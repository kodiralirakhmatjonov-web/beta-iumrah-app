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
        let dateEvidence: Bool
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
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 iumrah-beta/1.0"
        self.webView.layoutIfNeeded()
    }

    func run(timeoutSeconds: Double = AppConfig.hotelPriceProviderTimeoutSeconds) async throws -> HotelPriceObservation {
        let deadline = Date().addingTimeInterval(max(6, timeoutSeconds))
        let urls = provider.searchURLs(for: request)
        var lastError: Error = BotError.noMatchingHotel

        for (index, url) in urls.enumerated() {
            try Task.checkCancellation()
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 1 else { break }
            let attemptsLeft = max(1, urls.count - index)
            let slice: Double
            if index == 0, urls.count > 1 {
                slice = min(10, max(6, remaining - 6))
            } else {
                slice = max(4, remaining / Double(attemptsLeft))
            }
            do {
                return try await run(url: url, deadline: min(deadline, Date().addingTimeInterval(slice)))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func run(url: URL, deadline: Date) async throws -> HotelPriceObservation {
        webView.stopLoading()
        let timeout = max(4, deadline.timeIntervalSinceNow)
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout))

        var lastCard: ExtractedCard?
        while Date() < deadline {
            try Task.checkCancellation()
            if (try? await evaluate(HotelPriceBotScripts.detectChallenge) as? Bool) == true { throw BotError.challenge }

            if webView.url != nil {
                let script = HotelPriceBotScripts.extractExactHotel(
                    provider: provider,
                    hotelName: request.hotel.name,
                    roomName: nil,
                    sourceIdentity: request.pricingSource(for: provider.id),
                    checkInDate: Self.dayFormatter.string(from: request.checkIn),
                    checkOutDate: Self.dayFormatter.string(from: request.checkOut)
                )
                if let json = try? await evaluate(script) as? String,
                   !json.isEmpty,
                   let data = json.data(using: .utf8),
                   let card = try? JSONDecoder().decode(ExtractedCard.self, from: data) {
                    lastCard = card
                    if let observation = makeObservation(card: card, sourceURL: webView.url ?? url, requestedURL: url) { return observation }
                }
            }
            try? await Task.sleep(for: .milliseconds(700))
        }

        if let lastCard, makeObservation(card: lastCard, sourceURL: webView.url ?? url, requestedURL: url) == nil {
            throw BotError.noReliablePrice
        }
        if webView.url != nil { throw BotError.noMatchingHotel }
        throw BotError.timeout
    }

    private func makeObservation(card: ExtractedCard, sourceURL: URL, requestedURL: URL) -> HotelPriceObservation? {
        // Booking/Expedia often remove check-in/check-out query items after a
        // client-side redirect. The bot still initiated an exact dated request, so
        // preserve that evidence instead of rejecting a correct property price just
        // because the final browser URL was rewritten.
        let requestedDateEvidence = requestedURLContainsDates(requestedURL)
        guard card.score >= 0.62, card.dateEvidence || requestedDateEvidence else { return nil }
        // The current provider surface verifies the concrete hotel/stay/occupancy.
        // iumrah room category IDs are internal IDs, not Booking/Expedia inventory
        // identifiers, so missing room-name text on a search result must not turn a
        // valid hotel price into a false negative.
        let combined = "\(card.metaText) \(card.priceText) \(card.body)"
        guard let parsed = HotelPriceTextParser.parse(
            text: combined,
            priceText: card.priceText,
            metaText: card.metaText
        ) else { return nil }

        let resolvedSourceURL = URL(string: card.url).flatMap { candidate -> URL? in
            guard candidate.scheme?.lowercased() == "https", let host = candidate.host?.lowercased(), provider.id.accepts(host: host) else { return nil }
            return candidate
        } ?? sourceURL

        // Normalize the provider widget to ONE invariant before it reaches package
        // pricing: total cost for this requested hotel stay and room count. Downstream
        // code therefore never has to guess whether a scraped number was nightly.
        let calendar = Calendar(identifier: .gregorian)
        let nights = max(1, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: request.checkIn),
            to: calendar.startOfDay(for: request.checkOut)
        ).day ?? 1)
        let totalStayAmount: Decimal
        switch parsed.unit {
        case .totalStay:
            totalStayAmount = parsed.amount
        case .perRoomStay:
            totalStayAmount = parsed.amount * Decimal(max(1, request.rooms))
        case .perRoomNight:
            totalStayAmount = parsed.amount * Decimal(max(1, request.rooms)) * Decimal(nights)
        }
        guard totalStayAmount > 0 else { return nil }

        return HotelPriceObservation(
            id: UUID().uuidString,
            hotelId: request.hotel.id,
            hotelName: request.hotel.name,
            city: request.city,
            amount: totalStayAmount,
            currency: parsed.currency,
            unit: .totalStay,
            providerId: provider.id,
            providerName: provider.displayName,
            observedAt: Self.isoFormatter.string(from: Date()),
            checkInDate: Self.dayFormatter.string(from: request.checkIn),
            checkOutDate: Self.dayFormatter.string(from: request.checkOut),
            sourceURL: resolvedSourceURL.absoluteString,
            roomId: request.selectedRoomId,
            roomName: request.selectedRoomName
        )
    }


    private func requestedURLContainsDates(_ url: URL) -> Bool {
        let raw = url.absoluteString.lowercased()
        let checkIn = Self.dayFormatter.string(from: request.checkIn).lowercased()
        let checkOut = Self.dayFormatter.string(from: request.checkOut).lowercased()
        return raw.contains(checkIn) && raw.contains(checkOut)
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
