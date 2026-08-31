import Foundation

/// Searches official airline booking pages and returns verified fare components.
/// Generator V2 applies the existing package pricing formula locally on device.
@MainActor
struct OfficialFlightCandidateSearchService {
    func prepareRoundTrip(trip: TripDraft) async throws -> RoundTripFlightBotSession {
        try await RoundTripFlightBotCoordinator.shared.prepare(trip: trip)
    }

    func refreshInbound(trip: TripDraft) async throws -> FlightBotOrchestrator.SearchResult {
        try await RoundTripFlightBotCoordinator.shared.searchInboundForSelection(trip: trip)
    }
}
