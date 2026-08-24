import Foundation

@MainActor
final class RealFlightPackageSearchService: FlightSearchServicing {
    private let botService = OfficialFlightCandidateSearchService()
    private let packageEngine = RemotePackageEngineClient()
    private var session: RoundTripFlightBotSession?
    private var tripSignature: String?

    func searchOutbound(trip: TripDraft, hotel: HotelSummary) async throws -> [FlightOffer] {
        let currentSession = try await sessionFor(trip: trip)
        let response = try await packageEngine.quoteOutboundOptions(
            trip: trip,
            hotel: hotel,
            outbound: currentSession.outbound,
            inbound: currentSession.inbound
        )

        let offers = try bridge(
            candidates: currentSession.outbound,
            quotes: response.options,
            direction: .outbound
        )
        try enforceMinimum(offers)
        return Array(offers.prefix(AppConfig.flightBotPreferredOptions))
    }

    func searchReturn(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer) async throws -> [FlightOffer] {
        let currentSession = try await sessionFor(trip: trip)
        guard let sourceID = outbound.sourceCandidateID,
              let selectedCandidate = currentSession.outbound.first(where: { $0.id == sourceID }) else {
            throw FlightPricingBridgeError.candidateMissing(outbound.id)
        }

        let response = try await packageEngine.quoteReturnOptions(
            trip: trip,
            hotel: hotel,
            selectedOutbound: selectedCandidate,
            inbound: currentSession.inbound
        )

        let offers = try bridge(
            candidates: currentSession.inbound,
            quotes: response.options,
            direction: .inbound
        )
        try enforceMinimum(offers)
        return Array(offers.prefix(AppConfig.flightBotPreferredOptions))
    }

    private func sessionFor(trip: TripDraft) async throws -> RoundTripFlightBotSession {
        let signature = makeSignature(trip)
        if let session, tripSignature == signature { return session }
        let created = try await botService.prepareRoundTrip(trip: trip)
        self.session = created
        self.tripSignature = signature
        return created
    }

    private func bridge(
        candidates: [LiveFlightCandidate],
        quotes: [PublicFlightOptionQuote],
        direction: FlightDirection
    ) throws -> [FlightOffer] {
        let candidateMap = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let bridged = quotes.compactMap { quote -> FlightOffer? in
            guard let candidate = candidateMap[quote.candidateId] else { return nil }
            return FlightOffer(
                id: "real-\(direction.rawValue)-\(candidate.id)",
                direction: direction,
                airline: candidate.airline,
                flightNumber: candidate.flightNumber,
                origin: candidate.origin,
                destination: candidate.destination,
                departureAt: candidate.departureAt,
                arrivalAt: candidate.arrivalAt,
                stops: candidate.stops,
                durationMinutes: candidate.durationMinutes,
                totalPackagePrice: quote.pricePerPerson,
                currency: quote.currency,
                sourceLabel: "iumrah Flight Engine · \(candidate.providerName)",
                packageTotalPrice: quote.totalPackagePrice,
                quoteId: quote.quoteId,
                sourceCandidateID: candidate.id
            )
        }

        return bridged.sorted {
            if $0.totalPackagePrice != $1.totalPackagePrice {
                return $0.totalPackagePrice < $1.totalPackagePrice
            }
            if $0.stops != $1.stops { return $0.stops < $1.stops }
            return $0.departureAt < $1.departureAt
        }
    }

    private func enforceMinimum(_ offers: [FlightOffer]) throws {
        guard offers.count >= AppConfig.flightBotMinimumOptions else {
            throw FlightPricingBridgeError.insufficientQuotedOptions(
                found: offers.count,
                minimum: AppConfig.flightBotMinimumOptions
            )
        }
    }

    private func makeSignature(_ trip: TripDraft) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            trip.origin.uppercased(),
            formatter.string(from: trip.departureDate),
            formatter.string(from: trip.returnDate),
            trip.flexibility.rawValue,
            String(trip.adults),
            String(trip.children),
            String(trip.infants),
            trip.scope.rawValue,
        ].joined(separator: "|")
    }
}

@MainActor
final class AutomaticFlightSearchService: FlightSearchServicing {
    private let real = RealFlightPackageSearchService()
    private let sandbox = BetaFlightSearchService()
    private let packageEngine = RemotePackageEngineClient()
    private var remoteReady: Bool?

    func searchOutbound(trip: TripDraft, hotel: HotelSummary) async throws -> [FlightOffer] {
        switch AppConfig.flightEngineMode {
        case .sandbox:
            return try await sandbox.searchOutbound(trip: trip, hotel: hotel)
        case .officialWebBots:
            return try await real.searchOutbound(trip: trip, hotel: hotel)
        case .automatic:
            if await canUseRemoteEngine() {
                do {
                    return try await real.searchOutbound(trip: trip, hotel: hotel)
                } catch {
                    // Technical beta safety: provider/parser failures do not make
                    // the TestFlight build unusable while adapters are being tuned.
                    return try await sandbox.searchOutbound(trip: trip, hotel: hotel)
                }
            }
            return try await sandbox.searchOutbound(trip: trip, hotel: hotel)
        }
    }

    func searchReturn(trip: TripDraft, hotel: HotelSummary, outbound: FlightOffer) async throws -> [FlightOffer] {
        let isRealOutbound = outbound.sourceCandidateID != nil
        if isRealOutbound {
            return try await real.searchReturn(trip: trip, hotel: hotel, outbound: outbound)
        }
        return try await sandbox.searchReturn(trip: trip, hotel: hotel, outbound: outbound)
    }

    private func canUseRemoteEngine() async -> Bool {
        if let remoteReady { return remoteReady }
        do {
            let health = try await packageEngine.health()
            let ready = health.ok && health.hotelsDbConfigured && (health.pricingReady ?? false)
            remoteReady = ready
            return ready
        } catch {
            remoteReady = false
            return false
        }
    }
}
