import Foundation

protocol PackageQuoteServicing {
    func quote(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer, inbound: FlightOffer) async throws -> PackageQuote
}

struct BetaPackageQuoteService: PackageQuoteServicing {
    func quote(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer, inbound: FlightOffer) async throws -> PackageQuote {
        try await Task.sleep(for: .milliseconds(450))

        let travelers = max(1, trip.travelerCount)
        // This is deliberately only a UI sandbox total. Real internal component
        // costs and margin must remain in the server-side PackageQuote Engine.
        let blendedPerPerson = max(outbound.totalPackagePrice, inbound.totalPackagePrice)
        return PackageQuote(
            totalPackagePrice: blendedPerPerson * Decimal(travelers),
            pricePerPerson: blendedPerPerson,
            currency: outbound.currency,
            isEstimated: true
        )
    }
}
