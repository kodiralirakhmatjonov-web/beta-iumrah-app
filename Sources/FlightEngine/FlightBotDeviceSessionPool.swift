import Foundation
@preconcurrency import WebKit

struct FlightBotDeviceSessionKey: Hashable {
    let providerID: FlightBotProviderID
    let direction: FlightDirection
}

/// Owns the hidden browser sessions used by device-assisted airline adapters.
///
/// A session is keyed by carrier + direction so outbound discovery and return
/// prewarm may run at the same time without navigating the same WKWebView away
/// from each other. Flexible-date attempts reuse that same session. Human
/// verification is rendered with the exact same WKWebView instead of opening a
/// second browser and losing the airline's transient session state.
@MainActor
final class FlightBotDeviceSessionPool {
    struct Lease {
        let key: FlightBotDeviceSessionKey
        let token: UUID
        let webView: WKWebView
        let resumeCurrentPage: Bool
    }

    private final class Slot {
        let webView: WKWebView
        var activeToken: UUID?
        var resumeRequestSignature: String?
        var awaitingVerification = false
        var lastTouched = Date()

        init(webView: WKWebView) {
            self.webView = webView
        }
    }

    static let shared = FlightBotDeviceSessionPool()

    private var slots: [FlightBotDeviceSessionKey: Slot] = [:]
    private let maxRetainedIdleSessions = 4
    private let idleLifetime: TimeInterval = 20 * 60

    private init() {}

    func begin(provider: FlightBotProvider, request: FlightBotSearchRequest) -> Lease {
        prune()
        let key = FlightBotDeviceSessionKey(providerID: provider.id, direction: request.direction)
        let slot = slots[key] ?? makeSlot(for: key)
        let token = UUID()

        // A visible search may replace a hidden prewarm for the same carrier and
        // direction. The old runner observes its stale lease and exits before it
        // can continue manipulating this browser.
        if slot.activeToken != nil {
            slot.webView.stopLoading()
        }
        slot.activeToken = token
        slot.lastTouched = Date()

        let signature = resumeSignature(for: request)
        let canResume = slot.resumeRequestSignature == signature &&
            slot.webView.url.map(provider.acceptsSourceURL) == true
        if canResume {
            slot.resumeRequestSignature = nil
        }

        return Lease(key: key, token: token, webView: slot.webView, resumeCurrentPage: canResume)
    }

    func isCurrent(_ lease: Lease) -> Bool {
        slots[lease.key]?.activeToken == lease.token
    }

    func finish(_ lease: Lease) {
        guard let slot = slots[lease.key], slot.activeToken == lease.token else { return }
        slot.activeToken = nil
        slot.lastTouched = Date()
        prune()
    }

    func registerChallenge(_ challenge: FlightBotChallenge) {
        let key = challenge.sessionKey
        guard let slot = slots[key] else { return }
        slot.awaitingVerification = true
        slot.lastTouched = Date()
    }

    func webView(for challenge: FlightBotChallenge) -> WKWebView {
        let key = challenge.sessionKey
        if let existing = slots[key] {
            existing.lastTouched = Date()
            return existing.webView
        }

        let slot = makeSlot(for: key)
        slot.awaitingVerification = true
        slot.webView.load(URLRequest(url: challenge.url))
        return slot.webView
    }

    func verificationCompleted(_ challenge: FlightBotChallenge) {
        guard let slot = slots[challenge.sessionKey] else { return }
        slot.awaitingVerification = false
        slot.resumeRequestSignature = resumeSignature(for: challenge.request)
        slot.lastTouched = Date()
    }

    func verificationCancelled(_ challenge: FlightBotChallenge) {
        guard let slot = slots[challenge.sessionKey] else { return }
        slot.awaitingVerification = false
        slot.resumeRequestSignature = nil
        slot.lastTouched = Date()
        prune()
    }

    func reset() {
        for slot in slots.values {
            slot.webView.stopLoading()
        }
        slots.removeAll()
    }

    private func makeSlot(for key: FlightBotDeviceSessionKey) -> Slot {
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

        // Keep a real mobile layout viewport even while the provider browser is
        // off-screen. Provider-specific scripts deliberately ignore hidden DOM;
        // a zero-size WKWebView would otherwise make every legitimate control
        // appear invisible. Use WebKit's native iPhone user agent instead of a
        // custom "bot" fingerprint that could trigger airline anti-abuse rules.
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 375, height: 812),
            configuration: configuration
        )
        let slot = Slot(webView: webView)
        slots[key] = slot
        return slot
    }

    private func resumeSignature(for request: FlightBotSearchRequest) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: request.date).timeIntervalSince1970
        return [
            request.direction.rawValue,
            request.origin.uppercased(),
            request.destination.uppercased(),
            String(Int(day)),
            String(request.adults),
            String(request.children),
            String(request.infants),
            request.cabin.lowercased()
        ].joined(separator: "|")
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-idleLifetime)
        let expiredKeys = slots.compactMap { key, slot -> FlightBotDeviceSessionKey? in
            guard slot.activeToken == nil,
                  !slot.awaitingVerification,
                  slot.lastTouched < cutoff else { return nil }
            return key
        }
        for key in expiredKeys {
            slots[key]?.webView.stopLoading()
            slots.removeValue(forKey: key)
        }

        let idle = slots
            .filter { $0.value.activeToken == nil && !$0.value.awaitingVerification }
            .sorted { $0.value.lastTouched < $1.value.lastTouched }
        let excess = max(0, idle.count - maxRetainedIdleSessions)
        for (key, slot) in idle.prefix(excess) {
            slot.webView.stopLoading()
            slots.removeValue(forKey: key)
        }
    }
}
