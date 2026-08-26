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

        // Outbound and return-reference searches used to run sequentially. That
        // doubled the spinner time before the first flight list could appear.
        // Run them together: outbound needs a full list, while pricing only needs
        // one verified return candidate as a reference at this stage.
        async let outboundTask = FlightBotOrchestrator.shared.search(
            request: outboundRequest,
            flexibility: trip.flexibility,
            minimumResults: AppConfig.flightBotMinimumOptions,
            preferredResults: AppConfig.flightBotPreferredOptions
        )
        async let inboundTask = FlightBotOrchestrator.shared.search(
            request: inboundRequest,
            flexibility: trip.flexibility,
            minimumResults: 1,
            preferredResults: 3
        )

        let (outbound, inbound) = try await (outboundTask, inboundTask)

        return RoundTripFlightBotSession(
            id: UUID().uuidString,
            createdAt: Date(),
            outbound: outbound.candidates,
            inbound: inbound.candidates,
            outboundSummary: outbound.summary,
            inboundSummary: inbound.summary,
            challenges: outbound.blockedChallenges + inbound.blockedChallenges
        )
    }

    func searchInboundForSelection(trip: TripDraft) async throws -> FlightBotOrchestrator.SearchResult {
        try await FlightBotOrchestrator.shared.search(
            request: makeInboundRequest(trip: trip),
            flexibility: trip.flexibility,
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
