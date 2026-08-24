import SwiftUI
import WebKit

/// Reusable technical view for a provider's human-verification step.
/// It uses WKWebsiteDataStore.default(), the same persistent store as FlightBotRunner,
/// so a CAPTCHA/code completed by the user can be reused when the provider bot retries.
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
