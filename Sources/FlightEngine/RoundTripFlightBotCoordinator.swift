import Foundation

struct RoundTripFlightBotSession {
    let id: String
    let createdAt: Date
    let outbound: [LiveFlightCandidate]
    let inbound: [LiveFlightCandidate]
    let outboundSummary: FlightBotSearchSummary
    let inboundSummary: FlightBotSearchSummary
    let challenges: [FlightBotChallenge]

    func replacingInbound(with result: FlightBotOrchestrator.SearchResult) -> RoundTripFlightBotSession {
        RoundTripFlightBotSession(
            id: id,
            createdAt: createdAt,
            outbound: outbound,
            inbound: result.candidates,
            outboundSummary: outboundSummary,
            inboundSummary: result.summary,
            challenges: challenges + result.blockedChallenges
        )
    }
}

@MainActor
final class RoundTripFlightBotCoordinator {
    static let shared = RoundTripFlightBotCoordinator()

    private init() {}

    func prepare(trip: TripDraft) async throws -> RoundTripFlightBotSession {
        FlightBotChallengeCenter.shared.clear()

        let outboundRequest = makeOutboundRequest(trip: trip)
        let inboundRequest = makeInboundRequest(trip: trip)

        // Both directions are now discovered as complete verified itineraries.
        // There is no hidden fare-only / REF-* return candidate anymore.
        let outbound = try await FlightBotOrchestrator.shared.search(
            request: outboundRequest,
            flexibility: trip.flexibility,
            requirement: .displayable,
            minimumResults: AppConfig.flightBotMinimumOptions,
            preferredResults: AppConfig.flightBotPreferredOptions
        )

        // The outbound screen needs one real return fare to price complete
        // packages, not a full return list. Use the selected return date here;
        // ReturnFlightView later expands to the user's ±1–2-day preference.
        let inbound = try await FlightBotOrchestrator.shared.search(
            request: inboundRequest,
            flexibility: .exact,
            requirement: .displayable,
            minimumResults: 1,
            preferredResults: 1
        )

        return RoundTripFlightBotSession(
            id: UUID().uuidString,
            createdAt: Date(),
            outbound: outbound.candidates.filter(\.isDisplayableCandidate),
            inbound: inbound.candidates.filter(\.isDisplayableCandidate),
            outboundSummary: outbound.summary,
            inboundSummary: inbound.summary,
            challenges: outbound.blockedChallenges + inbound.blockedChallenges
        )
    }

    func searchInboundForSelection(trip: TripDraft) async throws -> FlightBotOrchestrator.SearchResult {
        try await FlightBotOrchestrator.shared.search(
            request: makeInboundRequest(trip: trip),
            flexibility: trip.flexibility,
            requirement: .displayable,
            minimumResults: AppConfig.flightBotMinimumOptions,
            preferredResults: AppConfig.flightBotPreferredOptions
        )
    }

    private func makeOutboundRequest(trip: TripDraft) -> FlightBotSearchRequest {
        FlightBotSearchRequest(
            direction: .outbound,
            origin: trip.originCode,
            destination: trip.outboundDestinationCode,
            date: trip.departureDate,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants
        )
    }

    private func makeInboundRequest(trip: TripDraft) -> FlightBotSearchRequest {
        FlightBotSearchRequest(
            direction: .inbound,
            origin: trip.returnOriginCode,
            destination: trip.originCode,
            date: trip.returnDate,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants
        )
    }
}
