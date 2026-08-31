import Foundation
@preconcurrency import WebKit

/// Runs one public flight-provider search inside a persistent WKWebView session.
/// Every provider has one absolute deadline. Complex airline SPAs often keep
/// WKWebView.isLoading=true because of trackers/streaming requests, so the bot
/// waits for a usable DOM instead of waiting for the entire page to become idle.
@MainActor
final class FlightBotRunner {
    enum BotError: LocalizedError {
        case invalidPage
        case challengeRequired(FlightBotChallenge)
        case noCandidates
        case timeout

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
            }
        }
    }

    private let provider: FlightBotProvider
    private let request: FlightBotSearchRequest
    private let requirement: FlightCandidateRequirement
    private let webView: WKWebView

    init(
        provider: FlightBotProvider,
        request: FlightBotSearchRequest,
        requirement: FlightCandidateRequirement = .displayable
    ) {
        self.provider = provider
        self.request = request
        self.requirement = requirement

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: FlightBotScripts.networkCaptureBootstrap,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 iumrah-beta/0.24"
    }

    func run(timeoutSeconds: Double = AppConfig.flightBotProviderTimeoutSeconds) async throws -> [LiveFlightCandidate] {
        let deadline = Date().addingTimeInterval(max(4, timeoutSeconds))
        let url = provider.searchURL(for: request)
        let urlRequest = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: max(4, timeoutSeconds)
        )

        guard provider.isOfficialCarrierSource else { throw BotError.invalidPage }

        webView.load(urlRequest)
        try await waitForUsableDOM(deadline: deadline)
        _ = try? await evaluate(FlightBotScripts.dismissNonSearchOverlays)
        try? await Task.sleep(for: .milliseconds(220))
        try await detectChallengeIfNeeded()

        // Prefer a stable first-party deep search URL when the carrier publishes
        // one (Qanot Sharq/WebSky). Other airline SPAs still use the hardened
        // form automation. This avoids needlessly rewriting a valid direct query.
        if !provider.usesDirectSearchURL {
            _ = try? await evaluate(FlightBotScripts.prepareSearch(provider: provider, request: request))
            try await sleepIfTime(.milliseconds(420), deadline: deadline)
            _ = try? await evaluate(FlightBotScripts.finalizeSearch(provider: provider, request: request))
        }
        try await sleepIfTime(.milliseconds(820), deadline: deadline)

        var best: [LiveFlightCandidate] = []
        var sawCandidateBlocks = false
        var detailExpansionPasses = 0
        var contextVerified = false

        while Date() < deadline {
            try Task.checkCancellation()
            try await detectChallengeIfNeeded()

            if !contextVerified,
               let state = try? await evaluate(FlightBotScripts.verifySearchContext(request: request)) as? [String: Any] {
                contextVerified = state["ok"] as? Bool ?? false
            }
            guard contextVerified else {
                try await sleepIfTime(.milliseconds(450), deadline: deadline)
                continue
            }

            // Exact flight numbers are often exposed only after opening itinerary
            // details. Re-run the bounded expansion because airline SPAs hydrate
            // result rows progressively.
            if detailExpansionPasses < 4 {
                let clicked = (try? await evaluate(FlightBotScripts.expandCandidateDetails)) as? Int ?? 0
                detailExpansionPasses += 1
                if clicked > 0 {
                    try? await Task.sleep(for: .milliseconds(320))
                }
            }

            var extractionBlocks: [String] = []
            if let domBlocks = try? await evaluate(FlightBotScripts.extractCandidateBlocks) as? [String] {
                extractionBlocks.append(contentsOf: domBlocks)
            }
            if let networkBlocks = try? await evaluate(FlightBotScripts.extractNetworkCandidateBlocks(request: request)) as? [String] {
                extractionBlocks.append(contentsOf: networkBlocks)
            }

            if !extractionBlocks.isEmpty {
                sawCandidateBlocks = true
                let parsed = FlightTextParser.candidates(
                    blocks: extractionBlocks,
                    provider: provider,
                    request: request,
                    sourceURL: webView.url ?? url,
                    requirement: requirement
                )
                let verified = deduplicate(parsed.filter(\.isDisplayableCandidate))
                if verified.count > best.count { best = verified }
                if best.count >= 3 { break }
            }

            try await sleepIfTime(.milliseconds(700), deadline: deadline)
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

    private func waitForUsableDOM(deadline: Date) async throws {
        let started = Date()

        while Date() < deadline {
            try Task.checkCancellation()

            if webView.url != nil {
                let ready = (try? await evaluate("document.readyState")) as? String
                if ready == "interactive" || ready == "complete" {
                    return
                }

                // Some booking sites continuously load analytics resources and never
                // report a clean navigation end. Once a URL and document exist, let
                // the search script proceed instead of burning the provider timeout.
                if Date().timeIntervalSince(started) >= 2.4 {
                    return
                }
            }

            try await sleepIfTime(.milliseconds(120), deadline: deadline)
        }

        if webView.url == nil { throw BotError.invalidPage }
        throw BotError.timeout
    }

    private func sleepIfTime(_ duration: Duration, deadline: Date) async throws {
        guard Date() < deadline else { throw BotError.timeout }
        try await Task.sleep(for: duration)
    }

    private func detectChallengeIfNeeded() async throws {
        let value = try? await evaluate(FlightBotScripts.detectChallenge)
        let challenged = value as? Bool ?? false
        guard challenged else { return }

        let challenge = FlightBotChallenge(
            provider: provider,
            url: webView.url ?? provider.baseURL
        )
        FlightBotChallengeCenter.shared.publish(challenge)
        throw BotError.challengeRequired(challenge)
    }

    private func evaluate(_ script: String) async throws -> Any? {
        try Task.checkCancellation()
        return try await webView.evaluateJavaScript(script)
    }
}
