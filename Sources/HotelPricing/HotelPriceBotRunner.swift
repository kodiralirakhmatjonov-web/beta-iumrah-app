import Foundation
@preconcurrency import WebKit

@MainActor
final class HotelPriceBotRunner {
    enum BotError: Error {
        case challenge
        case noMatchingHotel
        case noReliablePrice
        case timeout
    }

    private struct ExtractedCard: Decodable {
        let title: String
        let priceText: String
        let metaText: String
        let body: String
        let url: String
        let score: Double
        let roomEvidence: Bool
    }

    private let provider: HotelPriceProvider
    private let request: HotelPriceSearchRequest
    private let webView: WKWebView

    init(provider: HotelPriceProvider, request: HotelPriceSearchRequest) {
        self.provider = provider
        self.request = request
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 iumrah-beta/1.0"
    }

    func run(timeoutSeconds: Double = AppConfig.hotelPriceProviderTimeoutSeconds) async throws -> HotelPriceObservation {
        let deadline = Date().addingTimeInterval(max(6, timeoutSeconds))
        let url = provider.searchURL(for: request)
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeoutSeconds))

        var lastCard: ExtractedCard?
        while Date() < deadline {
            try Task.checkCancellation()
            if (try? await evaluate(HotelPriceBotScripts.detectChallenge) as? Bool) == true { throw BotError.challenge }

            if webView.url != nil {
                let script = HotelPriceBotScripts.extractExactHotel(
                    provider: provider,
                    hotelName: request.hotel.name,
                    roomName: request.selectedRoomName
                )
                if let json = try? await evaluate(script) as? String,
                   !json.isEmpty,
                   let data = json.data(using: .utf8),
                   let card = try? JSONDecoder().decode(ExtractedCard.self, from: data) {
                    lastCard = card
                    if let observation = makeObservation(card: card, sourceURL: webView.url ?? url) { return observation }
                }
            }
            try? await Task.sleep(for: .milliseconds(700))
        }

        if let lastCard, makeObservation(card: lastCard, sourceURL: webView.url ?? url) == nil {
            throw BotError.noReliablePrice
        }
        if webView.url != nil { throw BotError.noMatchingHotel }
        throw BotError.timeout
    }

    private func makeObservation(card: ExtractedCard, sourceURL: URL) -> HotelPriceObservation? {
        guard card.score >= 0.62 else { return nil }
        if request.selectedRoomId != nil {
            guard request.selectedRoomName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  card.roomEvidence else { return nil }
        }
        let combined = "\(card.metaText) \(card.priceText) \(card.body)"
        guard let parsed = HotelPriceTextParser.parse(text: combined, preferred: "\(card.metaText) \(card.priceText)") else { return nil }

        return HotelPriceObservation(
            id: UUID().uuidString,
            hotelId: request.hotel.id,
            hotelName: request.hotel.name,
            city: request.city,
            amount: parsed.amount,
            currency: parsed.currency,
            unit: parsed.unit,
            providerId: provider.id,
            providerName: provider.displayName,
            observedAt: Self.isoFormatter.string(from: Date()),
            checkInDate: Self.dayFormatter.string(from: request.checkIn),
            checkOutDate: Self.dayFormatter.string(from: request.checkOut),
            sourceURL: sourceURL.absoluteString,
            roomId: request.selectedRoomId,
            roomName: request.selectedRoomName
        )
    }


    private func evaluate(_ script: String) async throws -> Any? {
        try Task.checkCancellation()
        return try await webView.evaluateJavaScript(script)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
