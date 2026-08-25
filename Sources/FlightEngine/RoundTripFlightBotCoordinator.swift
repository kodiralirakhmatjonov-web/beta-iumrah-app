import Foundation

struct RoundTripFlightBotSession {
    let id: String
    let createdAt: Date
    let outbound: [LiveFlightCandidate]
    let inbound: [LiveFlightCandidate]
    let outboundSummary: FlightBotSearchSummary
    let inboundSummary: FlightBotSearchSummary
    let challenges: [FlightBotChallenge]
}

@MainActor
final class RoundTripFlightBotCoordinator {
    static let shared = RoundTripFlightBotCoordinator()

    private init() {}

    func prepare(trip: TripDraft) async throws -> RoundTripFlightBotSession {
        let outboundRequest = FlightBotSearchRequest(
            direction: .outbound,
            origin: trip.originCode,
            destination: trip.outboundDestinationCode,
            date: trip.departureDate,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants
        )

        let outbound = try await FlightBotOrchestrator.shared.search(
            request: outboundRequest,
            flexibility: trip.flexibility
        )

        let inboundRequest = FlightBotSearchRequest(
            direction: .inbound,
            origin: trip.returnOriginCode,
            destination: trip.originCode,
            date: trip.returnDate,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants
        )

        let inbound = try await FlightBotOrchestrator.shared.search(
            request: inboundRequest,
            flexibility: trip.flexibility
        )

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

}
