import Foundation

/// Searches live public booking pages and returns verified candidates. Raw fares
/// never become user-facing prices; Package Engine is still the only layer that
/// produces public package totals.
@MainActor
struct OfficialFlightCandidateSearchService {
    func prepareRoundTrip(trip: TripDraft) async throws -> RoundTripFlightBotSession {
        try await RoundTripFlightBotCoordinator.shared.prepare(trip: trip)
    }

    func refreshInbound(trip: TripDraft) async throws -> FlightBotOrchestrator.SearchResult {
        try await RoundTripFlightBotCoordinator.shared.searchInboundForSelection(trip: trip)
    }
}
