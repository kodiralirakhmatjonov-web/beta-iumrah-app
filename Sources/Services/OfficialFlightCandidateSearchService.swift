import Foundation

/// Technical 0.5 service. It searches live public booking pages and returns raw
/// verified flight candidates. It deliberately does NOT convert raw fares into
/// user-facing prices. Package-only pricing is performed by the server-side
/// Package Engine before any candidate is shown to a customer.
@MainActor
struct OfficialFlightCandidateSearchService {
    func prepareRoundTrip(trip: TripDraft) async throws -> RoundTripFlightBotSession {
        try await RoundTripFlightBotCoordinator.shared.prepare(trip: trip)
    }
}
