import Foundation
@preconcurrency import WebKit

/// Runs one public flight-provider search inside a persistent WKWebView session.
/// WebKit work is main-actor isolated. The runner intentionally uses polling for
/// navigation completion instead of delegate continuations/task-group races;
/// this is more predictable on Xcode 26 / iOS 26 while preserving persistent
/// cookies for a user-completed verification challenge.
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
    private let webView: WKWebView

    init(provider: FlightBotProvider, request: FlightBotSearchRequest) {
        self.provider = provider
        self.request = request

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 iumrah-beta/0.10"
    }

    func run(timeoutSeconds: Double = AppConfig.flightBotProviderTimeoutSeconds) async throws -> [LiveFlightCandidate] {
        let url = provider.searchURL(for: request)
        let urlRequest = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeoutSeconds
        )

        webView.load(urlRequest)
        try await waitForNavigation(timeoutSeconds: timeoutSeconds)
        try await detectChallengeIfNeeded()

        if provider.id != .googleFlights && provider.id != .skyscanner {
            _ = try? await evaluate(FlightBotScripts.submitSearch(provider: provider, request: request))
            try await Task.sleep(for: .milliseconds(850))
            try await waitForNavigation(timeoutSeconds: min(timeoutSeconds, 8))
            try await detectChallengeIfNeeded()
        } else {
            try await Task.sleep(for: .milliseconds(900))
        }

        var best: [LiveFlightCandidate] = []
        let retryDelays: [Duration] = [.zero, .milliseconds(900), .milliseconds(1400)]

        for delay in retryDelays {
            if delay != .zero {
                try await Task.sleep(for: delay)
            }

            try await detectChallengeIfNeeded()

            guard let blocks = try await evaluate(FlightBotScripts.extractCandidateBlocks) as? [String] else {
                continue
            }

            let parsed = FlightTextParser.candidates(
                blocks: blocks,
                provider: provider,
                request: request,
                sourceURL: webView.url ?? url
            )

            if parsed.count > best.count {
                best = parsed
            }
            if best.count >= 3 {
                break
            }
        }

        guard !best.isEmpty else {
            throw BotError.noCandidates
        }
        return best
    }

    private func waitForNavigation(timeoutSeconds: Double) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if !webView.isLoading, webView.url != nil {
                return
            }
            try await Task.sleep(for: .milliseconds(120))
        }

        if webView.url == nil {
            throw BotError.invalidPage
        }
        throw BotError.timeout
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
        try await webView.evaluateJavaScript(script)
    }
}
