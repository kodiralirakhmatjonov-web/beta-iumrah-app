import SwiftUI
@preconcurrency import WebKit

/// Human-verification surface for a provider. It shares WKWebsiteDataStore.default()
/// with FlightBotRunner so cookies/session state survive when the search is retried.
struct FlightChallengeWebView: UIViewRepresentable {
    let challenge: FlightBotChallenge

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: challenge.url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
