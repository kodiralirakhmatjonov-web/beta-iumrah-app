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
                let script = HotelPriceBotScripts.extractExactHotel(provider: provider, hotelName: request.hotel.name)
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
        let combined = "\(card.metaText) \(card.priceText) \(card.body)"
        guard let parsed = parseReliablePrice(combined, preferred: "\(card.metaText) \(card.priceText)") else { return nil }

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
            sourceURL: sourceURL.absoluteString
        )
    }

    private func parseReliablePrice(_ text: String, preferred: String) -> (amount: Decimal, currency: String, unit: HotelPriceUnit)? {
        let lower = text.lowercased()
        let preferredLower = preferred.lowercased()
        let hasStayContext = lower.range(of: #"(?:total|price for|for\s+\d+\s+nights?|\d+\s+nights?)"#, options: .regularExpression) != nil
        let perNight = lower.contains("per night") || lower.contains("/ night") || lower.contains("nightly")

        // Expedia commonly exposes both a nightly rate and a trip total. Prefer a
        // monetary value near an explicit total/stay phrase when available.
        if let total = moneyNearStayContext(in: text) {
            return (total.amount, total.currency, .totalStay)
        }

        let preferredValues = moneyValues(in: preferred)
        let allValues = preferredValues.isEmpty ? moneyValues(in: text) : preferredValues
        guard !allValues.isEmpty else { return nil }

        if perNight && !hasStayContext {
            // A clearly labelled nightly rate is safe to multiply server-side by
            // the selected room count and stay length.
            let value = allValues.min(by: { $0.amount < $1.amount })!
            return (value.amount, value.currency, .perRoomNight)
        }

        if hasStayContext || provider.id == .booking {
            // Booking's search card price is the requested stay/party total. If a
            // crossed-out old price is also visible, the lower current amount is
            // the actionable price shown to the customer.
            let value = allValues.min(by: { $0.amount < $1.amount })!
            return (value.amount, value.currency, .totalStay)
        }

        if provider.id == .expedia && preferredLower.contains("total") {
            let value = allValues.max(by: { $0.amount < $1.amount })!
            return (value.amount, value.currency, .totalStay)
        }

        return nil
    }

    private func moneyNearStayContext(in text: String) -> (amount: Decimal, currency: String)? {
        let patterns = [
            #"(?:total|price for|for\s+\d+\s+nights?)[^\n]{0,120}?(US\$|USD|\$|EUR|€|SAR|AED|GBP|£)\s*([0-9][0-9\s,.]*)"#,
            #"(US\$|USD|\$|EUR|€|SAR|AED|GBP|£)\s*([0-9][0-9\s,.]*)[^\n]{0,80}?(?:total|for\s+\d+\s+nights?)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = text as NSString
            guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 3 else { continue }
            let symbol = ns.substring(with: match.range(at: 1))
            let raw = ns.substring(with: match.range(at: 2))
            if let amount = decimal(raw) { return (amount, currency(symbol)) }
        }
        return nil
    }

    private func moneyValues(in text: String) -> [(amount: Decimal, currency: String)] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(US\$|USD|\$|EUR|€|SAR|AED|GBP|£)\s*([0-9][0-9\s,.]*)"#,
            options: [.caseInsensitive]
        ) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            guard let amount = decimal(ns.substring(with: match.range(at: 2))), amount > 0 else { return nil }
            return (amount, currency(ns.substring(with: match.range(at: 1))))
        }
    }

    private func decimal(_ raw: String) -> Decimal? {
        let cleaned = raw.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00a0}", with: "")
        let normalized: String
        if cleaned.contains(",") && cleaned.contains(".") {
            normalized = cleaned.replacingOccurrences(of: ",", with: "")
        } else if cleaned.filter({ $0 == "," }).count == 1, let comma = cleaned.lastIndex(of: ","), cleaned.distance(from: comma, to: cleaned.endIndex) <= 3 {
            normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = cleaned.replacingOccurrences(of: ",", with: "")
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func currency(_ symbol: String) -> String {
        switch symbol.uppercased() {
        case "EUR", "€": return "EUR"
        case "SAR": return "SAR"
        case "AED": return "AED"
        case "GBP", "£": return "GBP"
        default: return "USD"
        }
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
