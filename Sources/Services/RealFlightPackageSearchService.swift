import Foundation

enum FlightEngineAvailabilityError: LocalizedError, Equatable {
    case flightProviderNotConfigured
    case realOutboundRequired
    case noVerifiedFlights

    var errorDescription: String? {
        switch self {
        case .flightProviderNotConfigured: return "Flight API is not connected yet."
        case .realOutboundRequired: return "Return search requires a verified outbound flight."
        case .noVerifiedFlights: return "No verified flights were returned by the flight provider."
        }
    }
}

/// Production generator coordinator for one complete Umrah airfare journey.
/// Ignav returns two ordered legs with one trip-level fare; the UI still lets the
/// pilgrim choose outbound first and return second, but it never prices those legs
/// as two unrelated one-way products.
@MainActor
final class RealFlightPackageSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let flightProvider: FlightInventoryProviding
    private let hotelPriceService: HotelLivePriceSearchService

    private var activeSignature: String?
    private var cachedJourneys: [LiveFlightJourneyCandidate] = []
    private var cachedHotels: HotelPriceSearchSnapshot?

    init() {
        self.flightProvider = IgnavFlightInventoryProvider()
        self.hotelPriceService = HotelLivePriceSearchService()
    }

    init(flightProvider: FlightInventoryProviding, hotelPriceService: HotelLivePriceSearchService) {
        self.flightProvider = flightProvider
        self.hotelPriceService = hotelPriceService
    }

    init(flightProvider: FlightInventoryProviding) {
        self.flightProvider = flightProvider
        self.hotelPriceService = HotelLivePriceSearchService()
    }

    var currentHotelPriceSnapshot: HotelPriceSearchSnapshot? { cachedHotels }

    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        try await searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: { _ in })
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        try await searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: { _ in })
    }

    func searchOutboundProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        _ = makkahHotel
        _ = madinahHotel
        prepareForOutbound(trip)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .starting))
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))

        let request = makeJourneyRequest(trip)
        let pairs = journeyDatePairs(for: trip)
        do {
            var live = cachedJourneys
            let final = try await flightProvider.searchJourney(request: request, datePairs: pairs) { values in
                live = self.mergeJourneys(live, values)
                self.cachedJourneys = live
                let offers = self.rankedOutbound(self.outboundOffers(from: live), anchor: trip.departureDate)
                onUpdate(.init(
                    discoveredCandidates: live.map(\.outbound),
                    pricedOffers: offers,
                    isSearching: true,
                    status: offers.isEmpty ? .checkingAirlines : .comparingFares
                ))
            }
            live = mergeJourneys(live, final)
            cachedJourneys = live
            let offers = rankedOutbound(outboundOffers(from: live), anchor: trip.departureDate)
            onUpdate(.init(discoveredCandidates: live.map(\.outbound), pricedOffers: offers, isSearching: false, status: .continuing))
            if offers.isEmpty { throw FlightEngineAvailabilityError.noVerifiedFlights }
            return offers
        } catch FlightInventoryProviderError.notConfigured {
            onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: false, status: nil))
            throw FlightEngineAvailabilityError.flightProviderNotConfigured
        }
    }

    func searchReturnProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: FlightOffer,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        _ = makkahHotel
        _ = madinahHotel
        guard outbound.isVerifiedForBooking else { throw FlightEngineAvailabilityError.realOutboundRequired }

        var compatible = compatibleJourneys(with: outbound)
        if !compatible.isEmpty {
            let offers = rankedReturn(returnOffers(from: compatible), anchor: trip.returnDate)
            onUpdate(.init(discoveredCandidates: compatible.map(\.inbound), pricedOffers: offers, isSearching: false, status: .comparingFares))
            if !offers.isEmpty { return offers }
        }

        // Only a cache miss performs a narrower follow-up request. Exact-date flows
        // normally never reach this path: the first Ignav request already returned
        // complete outbound+return journeys and multiple alternatives.
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))
        let request = makeJourneyRequest(trip)
        let exactPair = FlightJourneyDatePair(outbound: trip.departureDate, inbound: trip.returnDate)
        do {
            let fresh = try await flightProvider.searchJourney(request: request, datePairs: [exactPair]) { values in
                self.cachedJourneys = self.mergeJourneys(self.cachedJourneys, values)
            }
            cachedJourneys = mergeJourneys(cachedJourneys, fresh)
            compatible = compatibleJourneys(with: outbound)
            let offers = rankedReturn(returnOffers(from: compatible), anchor: trip.returnDate)
            onUpdate(.init(discoveredCandidates: compatible.map(\.inbound), pricedOffers: offers, isSearching: false, status: .continuing))
            if offers.isEmpty { throw FlightEngineAvailabilityError.noVerifiedFlights }
            return offers
        } catch FlightInventoryProviderError.notConfigured {
            throw FlightEngineAvailabilityError.flightProviderNotConfigured
        }
    }

    func ensureHotelPrices(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        makkahRoomCapacity: Int?,
        madinahRoomId: String?,
        madinahRoomName: String?,
        madinahRoomCapacity: Int?,
        forceRefresh: Bool
    ) async -> HotelPriceSearchSnapshot {
        if !forceRefresh, let cachedHotels, isCompleteHotelSnapshot(cachedHotels, trip: trip) { return cachedHotels }
        if forceRefresh { cachedHotels = nil }
        let snapshot = await hotelPriceService.search(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            makkahRoomCapacity: makkahRoomCapacity,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName,
            madinahRoomCapacity: madinahRoomCapacity,
            forceRefresh: forceRefresh
        )
        if isCompleteHotelSnapshot(snapshot, trip: trip) { cachedHotels = snapshot }
        return snapshot
    }

    private func isCompleteHotelSnapshot(_ snapshot: HotelPriceSearchSnapshot, trip: TripDraft) -> Bool {
        !snapshot.makkah.isEmpty && (trip.scope != .makkahAndMadinah || !snapshot.madinah.isEmpty)
    }

    func invalidateHotelPrices() {
        cachedHotels = nil
        hotelPriceService.invalidateAll()
    }

    func invalidateFlightInventory() {
        activeSignature = nil
        cachedJourneys = []
    }

    func invalidateSession() {
        activeSignature = nil
        cachedJourneys = []
        cachedHotels = nil
        hotelPriceService.invalidateAll()
    }

    private func prepareForOutbound(_ trip: TripDraft) {
        let signature = makeSignature(trip)
        guard activeSignature != signature else { return }
        activeSignature = signature
        cachedJourneys = []
        cachedHotels = nil
    }

    private func compatibleJourneys(with outbound: FlightOffer) -> [LiveFlightJourneyCandidate] {
        cachedJourneys.filter { journey in
            guard let offer = offer(from: journey.outbound, journey: journey) else { return false }
            return offer.deduplicationKey == outbound.deduplicationKey
        }
    }

    private func outboundOffers(from journeys: [LiveFlightJourneyCandidate]) -> [FlightOffer] {
        cheapestUniqueOffers(journeys: journeys, leg: { $0.outbound })
    }

    private func returnOffers(from journeys: [LiveFlightJourneyCandidate]) -> [FlightOffer] {
        cheapestUniqueOffers(journeys: journeys, leg: { $0.inbound })
    }

    private func cheapestUniqueOffers(
        journeys: [LiveFlightJourneyCandidate],
        leg: (LiveFlightJourneyCandidate) -> LiveFlightCandidate
    ) -> [FlightOffer] {
        var byKey: [String: FlightOffer] = [:]
        for journey in journeys where journey.isDisplayableCandidate {
            guard let value = offer(from: leg(journey), journey: journey) else { continue }
            if let existing = byKey[value.deduplicationKey] {
                if value.currency == existing.currency && value.totalPackagePrice < existing.totalPackagePrice {
                    byKey[value.deduplicationKey] = value
                }
            } else {
                byKey[value.deduplicationKey] = value
            }
        }
        return Array(byKey.values)
    }

    private func offer(from candidate: LiveFlightCandidate, journey: LiveFlightJourneyCandidate) -> FlightOffer? {
        guard candidate.isDisplayableCandidate, journey.isDisplayableCandidate else { return nil }
        let value = FlightOffer(
            id: "fare:\(journey.providerItineraryID):\(candidate.direction.rawValue)",
            direction: candidate.direction,
            airline: candidate.airline,
            flightNumber: candidate.flightNumber,
            origin: candidate.origin,
            destination: candidate.destination,
            departureAt: candidate.departureAt,
            arrivalAt: candidate.arrivalAt,
            stops: candidate.stops,
            durationMinutes: candidate.durationMinutes,
            totalPackagePrice: journey.totalFare,
            currency: journey.currency,
            sourceLabel: journey.sourceName,
            packageTotalPrice: nil,
            quoteId: nil,
            sourceCandidateID: candidate.id,
            airlineCode: candidate.airlineCode,
            segments: candidate.segments,
            connectionAirports: candidate.connectionAirports,
            fareAmount: journey.totalFare,
            fareScope: journey.fareScope,
            fareObservedAt: journey.observedAt,
            fareSourceURL: candidate.sourceURL,
            providerItineraryID: journey.providerItineraryID,
            cabinClass: candidate.cabinClass,
            baggage: journey.baggage ?? candidate.baggage,
            requiresSelfTransfer: journey.requiresSelfTransfer ?? candidate.requiresSelfTransfer
        )
        return value.isVerifiedForBooking ? value : nil
    }

    private func mergeJourneys(_ lhs: [LiveFlightJourneyCandidate], _ rhs: [LiveFlightJourneyCandidate]) -> [LiveFlightJourneyCandidate] {
        var values = lhs.filter(\.isDisplayableCandidate)
        var ids = Set(values.map(\.providerItineraryID))
        for journey in rhs where journey.isDisplayableCandidate && ids.insert(journey.providerItineraryID).inserted {
            values.append(journey)
        }
        return values
    }

    private func rankedOutbound(_ offers: [FlightOffer], anchor: Date) -> [FlightOffer] {
        offers.sorted { lhs, rhs in
            let lo = abs(dayOffset(lhs.departureAt, from: anchor))
            let ro = abs(dayOffset(rhs.departureAt, from: anchor))
            if lo != ro { return lo < ro }
            // Price is the complete return/open-jaw itinerary price, so it is the
            // primary recommendation signal. Stops and duration break close ties.
            if lhs.currency == rhs.currency, lhs.totalPackagePrice != rhs.totalPackagePrice {
                return lhs.totalPackagePrice < rhs.totalPackagePrice
            }
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            if lhs.durationMinutes != rhs.durationMinutes { return lhs.durationMinutes < rhs.durationMinutes }
            return lhs.departureAt < rhs.departureAt
        }
    }

    private func rankedReturn(_ offers: [FlightOffer], anchor: Date) -> [FlightOffer] {
        rankedOutbound(offers, anchor: anchor)
    }

    private func journeyDatePairs(for trip: TripDraft) -> [FlightJourneyDatePair] {
        let calendar = Calendar.current
        let outboundDates = FlightDatePlanner.dates(anchor: trip.departureDate, flexibility: trip.flexibility, calendar: calendar)
        let baseDeparture = calendar.startOfDay(for: trip.departureDate)
        let baseReturn = calendar.startOfDay(for: trip.returnDate)
        return outboundDates.compactMap { outbound in
            let offset = calendar.dateComponents([.day], from: baseDeparture, to: calendar.startOfDay(for: outbound)).day ?? 0
            guard let inbound = calendar.date(byAdding: .day, value: offset, to: baseReturn), inbound >= outbound else { return nil }
            return FlightJourneyDatePair(outbound: outbound, inbound: inbound)
        }
    }

    private func dayOffset(_ date: Date, from anchor: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor), to: calendar.startOfDay(for: date)).day ?? 0
    }

    private func makeJourneyRequest(_ trip: TripDraft) -> FlightJourneySearchRequest {
        FlightJourneySearchRequest(
            outboundOrigin: trip.originCode,
            outboundDestination: trip.outboundDestinationCode,
            inboundOrigin: trip.returnOriginCode,
            inboundDestination: trip.originCode,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants,
            cabin: trip.effectiveFlightFilters.cabinClass.rawValue,
            filters: trip.effectiveFlightFilters
        )
    }

    private func makeSignature(_ trip: TripDraft) -> String {
        let formatter = ISO8601DateFormatter()
        let filters = trip.effectiveFlightFilters
        return [
            trip.originCode, trip.outboundDestinationCode, trip.returnOriginCode,
            formatter.string(from: trip.departureDate), formatter.string(from: trip.returnDate),
            trip.flexibility.rawValue, String(trip.adults), String(trip.children), String(trip.infants),
            filters.cabinClass.rawValue, filters.stops.rawValue,
            String(filters.minCarryOnBags), String(filters.minCheckedBags),
            filters.maxPriceUSD.map(String.init) ?? "-",
            filters.departureWindow.rawValue, filters.arrivalWindow.rawValue,
            filters.normalizedAirlinesInclude.joined(separator: ","), filters.normalizedAirlinesExclude.joined(separator: ","),
            filters.allowSelfTransfer ? "self-transfer" : "protected", filters.infantSeating.rawValue
        ].joined(separator: "|")
    }
}

@MainActor
final class AutomaticFlightSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let coordinator: RealFlightPackageSearchService

    init() { coordinator = RealFlightPackageSearchService() }
    init(flightProvider: FlightInventoryProviding) { coordinator = RealFlightPackageSearchService(flightProvider: flightProvider) }

    var currentHotelPriceSnapshot: HotelPriceSearchSnapshot? { coordinator.currentHotelPriceSnapshot }

    func ensureHotelPrices(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        makkahRoomCapacity: Int?,
        madinahRoomId: String?,
        madinahRoomName: String?,
        madinahRoomCapacity: Int?,
        forceRefresh: Bool
    ) async -> HotelPriceSearchSnapshot {
        await coordinator.ensureHotelPrices(
            trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId, makkahRoomName: makkahRoomName, makkahRoomCapacity: makkahRoomCapacity,
            madinahRoomId: madinahRoomId, madinahRoomName: madinahRoomName, madinahRoomCapacity: madinahRoomCapacity,
            forceRefresh: forceRefresh
        )
    }

    func invalidateHotelPrices() { coordinator.invalidateHotelPrices() }
    func invalidateFlightInventory() { coordinator.invalidateFlightInventory() }
    func invalidateSession() { coordinator.invalidateSession() }

    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        try await coordinator.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        try await coordinator.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
    }

    func searchOutboundProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        try await coordinator.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate)
    }

    func searchReturnProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: FlightOffer,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        try await coordinator.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate)
    }
}
