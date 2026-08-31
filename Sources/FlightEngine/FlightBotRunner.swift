import Foundation
@preconcurrency import WebKit

/// Runs one provider-specific airline search in the carrier's persistent device
/// browser session. Each carrier/direction owns one WKWebView so return prewarm
/// can run beside outbound discovery without navigating the same browser away.
@MainActor
final class FlightBotRunner {
    enum BotError: LocalizedError {
        case invalidPage
        case challengeRequired(FlightBotChallenge)
        case noCandidates
        case timeout
        case superseded

        var errorDescription: String? {
            switch self {
            case .invalidPage:
                return "Flight provider page could not be prepared."
            case .challengeRequired(let challenge):
                return "Human verification required by \(challenge.providerName)."
            case .noCandidates:
                return "Provider returned no parseable flight candidates."
            case .timeout:
                return "Flight provider search timed out."
            case .superseded:
                return "A newer flight search replaced this provider attempt."
            }
        }
    }

    private let provider: FlightBotProvider
    private let request: FlightBotSearchRequest
    private let requirement: FlightCandidateRequirement
    private let sessionPool = FlightBotDeviceSessionPool.shared

    init(
        provider: FlightBotProvider,
        request: FlightBotSearchRequest,
        requirement: FlightCandidateRequirement = .displayable
    ) {
        self.provider = provider
        self.request = request
        self.requirement = requirement
    }

    func run(timeoutSeconds: Double? = nil) async throws -> [LiveFlightCandidate] {
        let budget = max(4, timeoutSeconds ?? provider.deviceTimeoutSeconds)
        let deadline = Date().addingTimeInterval(budget)
        let url = provider.searchURL(for: request)
        let lease = sessionPool.begin(provider: provider, request: request)
        let webView = lease.webView
        defer { sessionPool.finish(lease) }

        guard provider.isOfficialCarrierSource else { throw BotError.invalidPage }
        try ensureCurrent(lease)

        if lease.resumeCurrentPage {
            // The user has just completed the carrier's own verification in this
            // exact browser. Do not reload and lose transient POST/session state;
            // parse the page the airline continued to after verification.
            try await waitForUsableDOM(webView: webView, lease: lease, deadline: deadline)
            guard let loadedURL = webView.url, provider.acceptsSourceURL(loadedURL) else { throw BotError.invalidPage }
            try await detectChallengeIfNeeded(webView: webView, lease: lease)
        } else {
            let urlRequest = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: budget
            )
            webView.load(urlRequest)
            try await waitForUsableDOM(webView: webView, lease: lease, deadline: deadline)
            guard let loadedURL = webView.url, provider.acceptsSourceURL(loadedURL) else { throw BotError.invalidPage }
            _ = try? await evaluate(FlightBotScripts.dismissNonSearchOverlays, webView: webView, lease: lease)
            try await sleepIfTime(.milliseconds(220), lease: lease, deadline: deadline)
            try await detectChallengeIfNeeded(webView: webView, lease: lease)

            // Search automation is provider-specific. Qanot uses its first-party
            // WebSky deep URL, while the other carriers expose dedicated form
            // adapters. There is deliberately no generic "submit nearest form"
            // fallback in the production runner.
            let adapter = FlightBotDeviceAdapterRegistry.adapter(for: provider)
            guard adapter.providerID == provider.id else { throw BotError.invalidPage }
            if let prepareScript = adapter.prepareSearch(provider: provider, request: request) {
                guard let prepared = try? await evaluate(
                    prepareScript,
                    webView: webView,
                    lease: lease
                ) as? [String: Any], prepared["ok"] as? Bool == true else {
                    throw BotError.invalidPage
                }
                try await sleepIfTime(.milliseconds(420), lease: lease, deadline: deadline)
            }
            if let finalizeScript = adapter.finalizeSearch(provider: provider, request: request) {
                guard let finalized = try? await evaluate(
                    finalizeScript,
                    webView: webView,
                    lease: lease
                ) as? [String: Any], finalized["ok"] as? Bool == true else {
                    throw BotError.invalidPage
                }
            }
            try await sleepIfTime(.milliseconds(820), lease: lease, deadline: deadline)
        }

        var best: [LiveFlightCandidate] = []
        var sawCandidateBlocks = false
        var detailExpansionPasses = 0
        var contextVerified = false

        while Date() < deadline {
            try Task.checkCancellation()
            try ensureCurrent(lease)
            try await detectChallengeIfNeeded(webView: webView, lease: lease)
            guard let currentURL = webView.url, provider.acceptsSourceURL(currentURL) else { throw BotError.invalidPage }

            if !contextVerified,
               let state = try? await evaluate(
                FlightBotScripts.verifySearchContext(request: request),
                webView: webView,
                lease: lease
               ) as? [String: Any] {
                contextVerified = state["ok"] as? Bool ?? false
            }
            guard contextVerified else {
                try await sleepIfTime(.milliseconds(450), lease: lease, deadline: deadline)
                continue
            }

            if detailExpansionPasses < 4 {
                let clicked = (try? await evaluate(
                    FlightBotScripts.expandCandidateDetails,
                    webView: webView,
                    lease: lease
                )) as? Int ?? 0
                detailExpansionPasses += 1
                if clicked > 0 {
                    try await sleepIfTime(.milliseconds(320), lease: lease, deadline: deadline)
                }
            }

            var extractionBlocks: [String] = []
            if let domBlocks = try? await evaluate(
                FlightBotScripts.extractCandidateBlocks(provider: provider, request: request),
                webView: webView,
                lease: lease
            ) as? [String] {
                extractionBlocks.append(contentsOf: domBlocks)
            }
            if let networkBlocks = try? await evaluate(
                FlightBotScripts.extractNetworkCandidateBlocks(provider: provider, request: request),
                webView: webView,
                lease: lease
            ) as? [String] {
                extractionBlocks.append(contentsOf: networkBlocks)
            }

            if !extractionBlocks.isEmpty {
                sawCandidateBlocks = true
                let dateFormatter = DateFormatter()
                dateFormatter.calendar = Calendar(identifier: .gregorian)
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let verifiedDate = dateFormatter.string(from: request.date)
                let contextualBlocks = extractionBlocks.map { "Verified search date: \(verifiedDate)\n\($0)" }
                let parsed = FlightTextParser.candidates(
                    blocks: contextualBlocks,
                    provider: provider,
                    request: request,
                    sourceURL: webView.url ?? url,
                    requirement: requirement
                )
                let verified = deduplicate(parsed.filter(\.isDisplayableCandidate))
                if verified.count > best.count { best = verified }
                if best.count >= 3 { break }
            }

            try await sleepIfTime(.milliseconds(700), lease: lease, deadline: deadline)
        }

        if !best.isEmpty { return best }
        if sawCandidateBlocks { throw BotError.noCandidates }
        if webView.url == nil { throw BotError.invalidPage }
        throw BotError.timeout
    }

    private func deduplicate(_ candidates: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            seen.insert(candidate.deduplicationKey).inserted
        }
    }

    private func waitForUsableDOM(
        webView: WKWebView,
        lease: FlightBotDeviceSessionPool.Lease,
        deadline: Date
    ) async throws {
        let started = Date()

        while Date() < deadline {
            try Task.checkCancellation()
            try ensureCurrent(lease)

            if webView.url != nil {
                let ready = (try? await evaluate("document.readyState", webView: webView, lease: lease)) as? String
                if ready == "interactive" || ready == "complete" {
                    return
                }

                if Date().timeIntervalSince(started) >= 2.4 {
                    return
                }
            }

            try await sleepIfTime(.milliseconds(120), lease: lease, deadline: deadline)
        }

        if webView.url == nil { throw BotError.invalidPage }
        throw BotError.timeout
    }

    private func sleepIfTime(
        _ duration: Duration,
        lease: FlightBotDeviceSessionPool.Lease,
        deadline: Date
    ) async throws {
        try ensureCurrent(lease)
        guard Date() < deadline else { throw BotError.timeout }
        try await Task.sleep(for: duration)
        try ensureCurrent(lease)
    }

    private func detectChallengeIfNeeded(
        webView: WKWebView,
        lease: FlightBotDeviceSessionPool.Lease
    ) async throws {
        let value = try? await evaluate(FlightBotScripts.detectChallenge, webView: webView, lease: lease)
        let challenged = value as? Bool ?? false
        guard challenged else { return }

        let challenge = FlightBotChallenge(
            provider: provider,
            request: request,
            url: webView.url ?? provider.baseURL
        )
        sessionPool.registerChallenge(challenge)
        throw BotError.challengeRequired(challenge)
    }

    private func ensureCurrent(_ lease: FlightBotDeviceSessionPool.Lease) throws {
        if !sessionPool.isCurrent(lease) { throw BotError.superseded }
    }

    private func evaluate(
        _ script: String,
        webView: WKWebView,
        lease: FlightBotDeviceSessionPool.Lease
    ) async throws -> Any? {
        try Task.checkCancellation()
        try ensureCurrent(lease)
        let value = try await webView.evaluateJavaScript(script)
        try ensureCurrent(lease)
        return value
    }
}
