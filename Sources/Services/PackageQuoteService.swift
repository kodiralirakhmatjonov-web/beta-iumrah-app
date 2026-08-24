import Foundation

@MainActor
protocol PackageQuoteServicing {
    func quote(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer, inbound: FlightOffer) async throws -> PackageQuote
}

@MainActor
struct BetaPackageQuoteService: PackageQuoteServicing {
    func quote(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer, inbound: FlightOffer) async throws -> PackageQuote {
        try await Task.sleep(for: .milliseconds(450))

        if let exactTotal = inbound.packageTotalPrice, inbound.quoteId != nil {
            return PackageQuote(
                totalPackagePrice: exactTotal,
                pricePerPerson: inbound.totalPackagePrice,
                currency: inbound.currency,
                isEstimated: false
            )
        }

        let travelers = max(1, trip.travelerCount)
        let blendedPerPerson = max(outbound.totalPackagePrice, inbound.totalPackagePrice)
        return PackageQuote(
            totalPackagePrice: blendedPerPerson * Decimal(travelers),
            pricePerPerson: blendedPerPerson,
            currency: inbound.currency,
            isEstimated: true
        )
    }
}
