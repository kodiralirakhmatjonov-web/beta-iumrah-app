import Foundation

@MainActor
protocol PackageQuoteServicing {
    func quote(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer, inbound: FlightOffer) async throws -> PackageQuote
}

enum PackageQuoteServiceError: LocalizedError {
    case localPricingRequired

    var errorDescription: String? {
        "Final package pricing is calculated only by LocalPackagePricingEngine after verified flight and hotel costs are available."
    }
}

@MainActor
struct LocalOnlyPackageQuoteService: PackageQuoteServicing {
    func quote(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer, inbound: FlightOffer) async throws -> PackageQuote {
        throw PackageQuoteServiceError.localPricingRequired
    }
}
