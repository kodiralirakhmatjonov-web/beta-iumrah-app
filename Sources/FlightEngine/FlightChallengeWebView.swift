import SwiftUI
@preconcurrency import WebKit

/// Presents the exact WKWebView session that encountered the airline's human
/// verification. Reusing the same browser is critical: CAPTCHA/session tokens may
/// live in transient page state and are not guaranteed to survive a second load.
@MainActor
struct FlightChallengeWebView: UIViewRepresentable {
    let challenge: FlightBotChallenge

    func makeUIView(context: Context) -> WKWebView {
        let webView = FlightBotDeviceSessionPool.shared.webView(for: challenge)
        webView.removeFromSuperview()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
