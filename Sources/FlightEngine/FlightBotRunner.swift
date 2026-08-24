import Foundation
import WebKit

@MainActor
final class FlightBotRunner: NSObject, WKNavigationDelegate {
    enum BotError: LocalizedError {
        case invalidPage
        case challengeRequired(FlightBotChallenge)
        case noCandidates
        case timeout
        case navigation(Error)

        var errorDescription: String? {
            switch self {
            case .invalidPage: return "Flight provider page could not be prepared."
            case .challengeRequired(let challenge): return "Human verification required by \(challenge.providerName)."
            case .noCandidates: return "Provider returned no parseable flight candidates."
            case .timeout: return "Flight provider search timed out."
            case .navigation(let error): return error.localizedDescription
            }
        }
    }

    private let provider: FlightBotProvider
    private let request: FlightBotSearchRequest
    private let webView: WKWebView
    private var didSubmit = false
    private var finishedContinuation: CheckedContinuation<Void, Error>?

    init(provider: FlightBotProvider, request: FlightBotSearchRequest) {
        self.provider = provider
        self.request = request
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        self.webView.navigationDelegate = self
    }

    func run(timeoutSeconds: Double = 24) async throws -> [LiveFlightCandidate] {
        let url = provider.searchURL(for: request)
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutSeconds))

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [weak self] in
                guard let self else { return }
                try await self.waitUntilInitialNavigationFinishes()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                throw BotError.timeout
            }
            _ = try await group.next()
            group.cancelAll()
        }

        try await detectChallengeIfNeeded()

        if provider.id != .googleFlights && provider.id != .skyscanner {
            _ = try? await evaluate(FlightBotScripts.submitSearch(provider: provider, request: request))
            didSubmit = true
            try await Task.sleep(for: .seconds(3))
            try await detectChallengeIfNeeded()
        } else {
            try await Task.sleep(for: .seconds(2.5))
        }

        var best: [LiveFlightCandidate] = []
        for delay in [0.0, 2.0, 3.0] {
            if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
            try await detectChallengeIfNeeded()
            if let blocks = try await evaluate(FlightBotScripts.extractCandidateBlocks) as? [String] {
                let parsed = FlightTextParser.candidates(
                    blocks: blocks,
                    provider: provider,
                    request: request,
                    sourceURL: webView.url ?? url
                )
                if parsed.count > best.count { best = parsed }
                if best.count >= 3 { break }
            }
        }

        guard !best.isEmpty else { throw BotError.noCandidates }
        return best
    }

    private func waitUntilInitialNavigationFinishes() async throws {
        if webView.isLoading == false, webView.url != nil { return }
        try await withCheckedThrowingContinuation { continuation in
            finishedContinuation = continuation
        }
    }

    private func detectChallengeIfNeeded() async throws {
        let challenged = (try? await evaluate(FlightBotScripts.detectChallenge) as? Bool) ?? false
        guard challenged else { return }
        let challenge = FlightBotChallenge(provider: provider, url: webView.url ?? provider.baseURL)
        FlightBotChallengeCenter.shared.publish(challenge)
        throw BotError.challengeRequired(challenge)
    }

    private func evaluate(_ script: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result) }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let continuation = finishedContinuation {
            finishedContinuation = nil
            continuation.resume()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let continuation = finishedContinuation {
            finishedContinuation = nil
            continuation.resume(throwing: BotError.navigation(error))
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let continuation = finishedContinuation {
            finishedContinuation = nil
            continuation.resume(throwing: BotError.navigation(error))
        }
    }
}
