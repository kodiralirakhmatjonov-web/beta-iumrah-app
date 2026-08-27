import Foundation

enum FlightEngineAvailabilityError: LocalizedError {
    case packageEngineUnavailable(String)
    case makkahPricingMissing
    case madinahPricingMissing
    case realOutboundRequired

    var errorDescription: String? {
        switch self {
        case .packageEngineUnavailable(let message):
            return "Сервис расчёта недоступен: \(message)"
        case .makkahPricingMissing:
            return "Для Мекки пока не настроен основной отель с внутренней ценой."
        case .madinahPricingMissing:
            return "Для выбранного маршрута Мекка + Медина пока не настроена внутренняя цена основного отеля в Медине."
        case .realOutboundRequired:
            return "Обратный поиск требует реальный выбранный рейс туда. Повторите поиск перелёта."
        }
    }
}

@MainActor
final class RealFlightPackageSearchService: FlightSearchServicing {
    private let botService = OfficialFlightCandidateSearchService()
    private let packageEngine = RemotePackageEngineClient()
    private var session: RoundTripFlightBotSession?
    private var tripSignature: String?
    private var verifiedSignature: String?

    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        try await ensureBackendReady(for: trip)
        let currentSession = try await sessionFor(trip: trip)
        let response = try await packageEngine.quoteOutboundOptions(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            outbound: currentSession.outbound,
            inbound: currentSession.inbound
        )

        let offers = try bridge(
            candidates: currentSession.outbound,
            quotes: response.options,
            direction: .outbound
        )
        try enforceMinimum(offers)
        let ranked = rankForRecommendation(offers, anchor: trip.departureDate)
        return Array(ranked.prefix(AppConfig.flightBotPreferredOptions))
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        try await ensureBackendReady(for: trip)
        var currentSession = try await sessionFor(trip: trip)
        guard let sourceID = outbound.sourceCandidateID,
              let selectedCandidate = currentSession.outbound.first(where: { $0.id == sourceID }) else {
            throw FlightEngineAvailabilityError.realOutboundRequired
        }

        // The first screen only needs one verified return candidate to calculate
        // a complete package reference price. When the pilgrim actually opens
        // return selection, expand that side to a full list if necessary.
        if currentSession.inbound.count < AppConfig.flightBotMinimumOptions {
            let refreshed = try await botService.refreshInbound(trip: trip)
            currentSession = currentSession.replacingInbound(with: refreshed)
            self.session = currentSession
        }

        let response = try await packageEngine.quoteReturnOptions(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            selectedOutbound: selectedCandidate,
            inbound: currentSession.inbound
        )

        let offers = try bridge(
            candidates: currentSession.inbound,
            quotes: response.options,
            direction: .inbound
        )
        try enforceMinimum(offers)
        let ranked = rankForRecommendation(offers, anchor: trip.returnDate)
        return Array(ranked.prefix(AppConfig.flightBotPreferredOptions))
    }

    func invalidateSession() {
        session = nil
        tripSignature = nil
    }

    private func ensureBackendReady(for trip: TripDraft) async throws {
        let signature = makeSignature(trip)
        if verifiedSignature == signature { return }
        do {
            let health = try await packageEngine.health()
            guard health.ok, health.hotelsDbConfigured else {
                throw FlightEngineAvailabilityError.packageEngineUnavailable("База отелей временно недоступна.")
            }
            let estimateFallback = health.legacyEstimateFallbackEnabled ?? false
            guard (health.flightOptionQuotingReady ?? health.pricingReady ?? false) || estimateFallback else {
                throw FlightEngineAvailabilityError.packageEngineUnavailable("Расчёт вариантов перелёта временно недоступен.")
            }
            guard (health.makkahPricingReady ?? health.pricingReady ?? false) || estimateFallback else {
                throw FlightEngineAvailabilityError.makkahPricingMissing
            }
            if trip.scope == .makkahAndMadinah,
               !(health.madinahPricingReady ?? false),
               !estimateFallback {
                throw FlightEngineAvailabilityError.madinahPricingMissing
            }
            verifiedSignature = signature
        } catch let error as FlightEngineAvailabilityError {
            throw error
        } catch {
            throw FlightEngineAvailabilityError.packageEngineUnavailable(error.localizedDescription)
        }
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
                sourceCandidateID: candidate.id,
                airlineCode: candidate.airlineCode,
                segments: candidate.segments
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


    private func rankForRecommendation(_ offers: [FlightOffer], anchor: Date) -> [FlightOffer] {
        offers.sorted { lhs, rhs in
            let leftDay = abs(Calendar.current.startOfDay(for: lhs.departureAt).timeIntervalSince(Calendar.current.startOfDay(for: anchor)))
            let rightDay = abs(Calendar.current.startOfDay(for: rhs.departureAt).timeIntervalSince(Calendar.current.startOfDay(for: anchor)))
            if leftDay != rightDay { return leftDay < rightDay }
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            if lhs.totalPackagePrice != rhs.totalPackagePrice { return lhs.totalPackagePrice < rhs.totalPackagePrice }
            return lhs.departureAt < rhs.departureAt
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
            trip.originCode,
            formatter.string(from: trip.departureDate),
            formatter.string(from: trip.returnDate),
            trip.flexibility.rawValue,
            String(trip.adults),
            String(trip.children),
            String(trip.infants),
            trip.scope.rawValue,
            trip.arrivalAirport.rawValue,
        ].joined(separator: "|")
    }
}

@MainActor
final class AutomaticFlightSearchService: FlightSearchServicing {
    private let real = RealFlightPackageSearchService()
    private let sandbox = BetaFlightSearchService()
    private let packageEngine = RemotePackageEngineClient()
    private var remoteReady: Bool?

    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        switch AppConfig.flightEngineMode {
        case .sandbox:
            return try await sandbox.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        case .officialWebBots:
            return try await real.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        case .automatic:
            guard await canUseRemoteEngine() else {
                return try await sandbox.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
            }
            return try await real.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        }
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        switch AppConfig.flightEngineMode {
        case .sandbox:
            return try await sandbox.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
        case .officialWebBots:
            guard outbound.sourceCandidateID != nil else {
                throw FlightEngineAvailabilityError.realOutboundRequired
            }
            return try await real.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
        case .automatic:
            if outbound.sourceCandidateID != nil {
                return try await real.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
            }
            return try await sandbox.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
        }
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
