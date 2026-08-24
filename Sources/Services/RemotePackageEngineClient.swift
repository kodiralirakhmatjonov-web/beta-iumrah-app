import Foundation

struct RemotePackageEngineClient {
    private let api = APIClient.shared

    func quote(
        trip: TripDraft,
        makkahHotelID: String?,
        madinahHotelID: String?,
        outbound: NormalizedFlightLegCost,
        inbound: NormalizedFlightLegCost
    ) async throws -> PublicPackageQuoteResponse {
        let stay = TripStayPlanner.breakdown(for: trip)
        let request = ConsumerPackageQuoteRequest(
            tier: trip.packageTier.rawValue,
            hotelStars: trip.hotelStars,
            includeMadinah: trip.scope == .makkahAndMadinah,
            totalDays: stay.totalDays,
            nights: .init(makkah: stay.makkahNights, madinah: stay.madinahNights),
            travelers: .init(adults: trip.adults, children: trip.children, infants: trip.infants, rooms: trip.rooms),
            flights: .init(outbound: outbound, inbound: inbound),
            primaryHotelIds: .init(makkah: makkahHotelID, madinah: madinahHotelID)
        )
        return try await api.post(AppConfig.packageQuotePath, body: request)
    }
}
