import Foundation

struct HotelStorefrontService {
    private let api = APIClient.shared

    func flightBoard(origin: String = "TAS") async throws -> StorefrontFlightBoardResponse {
        try await api.get(
            "/api/package/storefront/flights",
            query: [URLQueryItem(name: "origin", value: origin)]
        )
    }

    func quote(
        hotel: HotelSummary,
        tier: PackageTier,
        baseline: StorefrontFlightBaseline
    ) throws -> HotelStorefrontQuote {
        guard baseline.currency.uppercased() == "USD", baseline.perTravelerFareUsd > 0 else {
            throw LocalPricingError.invalidFlightFare
        }
        guard let catalog = hotel.price,
              catalog.isFresh,
              let nightly = catalog.nightlyUSD,
              nightly.isFinite,
              nightly > 0 else {
            throw LocalPricingError.missingHotelPrice(hotel.city)
        }

        let nights = max(1, catalog.nights ?? fallbackNights(for: hotel.city))
        let rooms = max(1, catalog.rooms ?? 1)
        let travelers = max(1, baseline.travelers)
        let nightlyDecimal = Decimal(nightly)
        let fareDecimal = Decimal(baseline.perTravelerFareUsd)
        let packageQuote = try LocalPackagePricingEngine.calculateStorefrontPreview(
            tier: tier,
            flightFarePerTravelerUsd: fareDecimal,
            hotelNightlyUsd: nightlyDecimal,
            hotelNights: nights,
            rooms: rooms,
            travelers: travelers
        )
        return HotelStorefrontQuote(
            tier: tier,
            packageQuote: packageQuote,
            hotelNightlyUsd: nightlyDecimal,
            hotelNights: nights,
            rooms: rooms,
            travelers: travelers,
            flightFarePerTravelerUsd: fareDecimal
        )
    }

    private func fallbackNights(for city: String) -> Int {
        city.lowercased().contains("mad") ? 2 : 5
    }
}
