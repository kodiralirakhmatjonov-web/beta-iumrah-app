import Foundation

enum FlightEngineAvailabilityError: LocalizedError, Equatable {
    case flightProviderNotConfigured
    case realOutboundRequired
    case noVerifiedFlights

    var errorDescription: String? {
        switch self {
        case .flightProviderNotConfigured:
            return "Flight API is not connected yet."
        case .realOutboundRequired:
            return "Return search requires a verified outbound flight."
        case .noVerifiedFlights:
            return "No verified flights were returned by the flight provider."
        }
    }
}

/// Clean generator coordinator.
///
/// Responsibilities kept here:
/// - start flight inventory and Primary Hotel live-price verification in parallel;
/// - prewarm the return flight search while outbound is on screen;
/// - normalize/deduplicate provider results;
/// - never calculate the final Umrah package price (LocalPackagePricingEngine owns it).
///
/// Airline-specific server/WebKit bots are retired. Flight inventory now enters
/// the generator through a single Ignav-backed FlightInventoryProviding boundary.
@MainActor
final class RealFlightPackageSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let flightProvider: FlightInventoryProviding
    private let hotelPriceService: HotelLivePriceSearchService

    private var activeSignature: String?
    private var cachedInbound: [LiveFlightCandidate] = []
    private var cachedHotels: HotelPriceSearchSnapshot?
    private var inboundPrewarmTask: Task<[LiveFlightCandidate], Never>?
    private var hotelPriceTask: Task<HotelPriceSearchSnapshot, Never>?

    init() {
        self.flightProvider = IgnavFlightInventoryProvider()
        self.hotelPriceService = HotelLivePriceSearchService()
    }

    init(
        flightProvider: FlightInventoryProviding,
        hotelPriceService: HotelLivePriceSearchService
    ) {
        self.flightProvider = flightProvider
        self.hotelPriceService = hotelPriceService
    }

    init(flightProvider: FlightInventoryProviding) {
        self.flightProvider = flightProvider
        self.hotelPriceService = HotelLivePriceSearchService()
    }

    var currentHotelPriceSnapshot: HotelPriceSearchSnapshot? { cachedHotels }

    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        try await searchOutboundProgressive(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            onUpdate: { _ in }
        )
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        try await searchReturnProgressive(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            outbound: outbound,
            onUpdate: { _ in }
        )
    }

    func searchOutboundProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        prepare(for: trip)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .starting))

        // Hotel verification starts before awaiting flight inventory so both
        // components run concurrently once Ignav is connected.
        startHotelPriceCheck(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        startInboundPrewarm(trip: trip)

        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingHotels))
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))

        let request = makeOutboundRequest(trip)
        let dates = FlightDatePlanner.dates(anchor: trip.departureDate, flexibility: trip.flexibility)

        do {
            var live: [LiveFlightCandidate] = []
            let final = try await flightProvider.search(request: request, dates: dates) { values in
                live = self.merge(live, values)
                let offers = self.ranked(live.compactMap(self.offer(from:)), anchor: trip.departureDate)
                onUpdate(.init(
                    discoveredCandidates: live,
                    pricedOffers: offers,
                    isSearching: true,
                    status: offers.isEmpty ? .checkingAirlines : .comparingFares
                ))
            }
            live = merge(live, final)
            let offers = ranked(live.compactMap(offer(from:)), anchor: trip.departureDate)
            onUpdate(.init(discoveredCandidates: live, pricedOffers: offers, isSearching: false, status: .continuing))
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
        guard outbound.isVerifiedForBooking else { throw FlightEngineAvailabilityError.realOutboundRequired }
        prepare(for: trip)
        startHotelPriceCheck(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)

        if let prewarm = inboundPrewarmTask {
            let prewarmed = await prewarm.value
            inboundPrewarmTask = nil
            cachedInbound = merge(cachedInbound, prewarmed)
        }

        if !cachedInbound.isEmpty {
            let offers = ranked(cachedInbound.compactMap(offer(from:)), anchor: trip.returnDate)
            onUpdate(.init(discoveredCandidates: cachedInbound, pricedOffers: offers, isSearching: true, status: .continuing))
        } else {
            onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))
        }

        let request = makeInboundRequest(trip)
        let dates = FlightDatePlanner.dates(anchor: trip.returnDate, flexibility: trip.flexibility)

        do {
            var live = cachedInbound
            let final = try await flightProvider.search(request: request, dates: dates) { values in
                live = self.merge(live, values)
                self.cachedInbound = live
                let offers = self.ranked(live.compactMap(self.offer(from:)), anchor: trip.returnDate)
                onUpdate(.init(
                    discoveredCandidates: live,
                    pricedOffers: offers,
                    isSearching: true,
                    status: offers.isEmpty ? .checkingAirlines : .comparingFares
                ))
            }
            live = merge(live, final)
            cachedInbound = live
            let offers = ranked(live.compactMap(offer(from:)), anchor: trip.returnDate)
            onUpdate(.init(discoveredCandidates: live, pricedOffers: offers, isSearching: false, status: .continuing))
            if offers.isEmpty { throw FlightEngineAvailabilityError.noVerifiedFlights }
            return offers
        } catch FlightInventoryProviderError.notConfigured {
            onUpdate(.init(discoveredCandidates: cachedInbound, pricedOffers: [], isSearching: false, status: nil))
            throw FlightEngineAvailabilityError.flightProviderNotConfigured
        }
    }

    func ensureHotelPrices(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        madinahRoomId: String?,
        madinahRoomName: String?,
        forceRefresh: Bool
    ) async -> HotelPriceSearchSnapshot {
        if forceRefresh {
            hotelPriceTask?.cancel()
            hotelPriceTask = nil
            cachedHotels = nil
        } else if let hotelPriceTask {
            let snapshot = await hotelPriceTask.value
            self.hotelPriceTask = nil
            if isCompleteHotelSnapshot(snapshot, trip: trip) {
                cachedHotels = snapshot
                return snapshot
            }
            // A partial prewarm (for example Makkah succeeded but Madinah hit a
            // challenge) is not a valid final-pricing snapshot. Retry the selected
            // hotels immediately instead of carrying the partial result forward.
        } else if let cachedHotels, isCompleteHotelSnapshot(cachedHotels, trip: trip) {
            return cachedHotels
        }

        let snapshot = await hotelPriceService.search(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName,
            forceRefresh: forceRefresh
        )
        if isCompleteHotelSnapshot(snapshot, trip: trip) { cachedHotels = snapshot }
        return snapshot
    }

    private func isCompleteHotelSnapshot(_ snapshot: HotelPriceSearchSnapshot, trip: TripDraft) -> Bool {
        !snapshot.makkah.isEmpty && (trip.scope != .makkahAndMadinah || !snapshot.madinah.isEmpty)
    }

    func invalidateHotelPrices() {
        hotelPriceTask?.cancel()
        hotelPriceTask = nil
        cachedHotels = nil
        hotelPriceService.invalidateAll()
    }

    func invalidateFlightInventory() {
        inboundPrewarmTask?.cancel()
        inboundPrewarmTask = nil
        activeSignature = nil
        cachedInbound = []
    }

    func invalidateSession() {
        inboundPrewarmTask?.cancel()
        hotelPriceTask?.cancel()
        inboundPrewarmTask = nil
        hotelPriceTask = nil
        activeSignature = nil
        cachedInbound = []
        cachedHotels = nil
        hotelPriceService.invalidateAll()
    }

    private func prepare(for trip: TripDraft) {
        let signature = makeSignature(trip)
        guard activeSignature != signature else { return }
        inboundPrewarmTask?.cancel()
        hotelPriceTask?.cancel()
        inboundPrewarmTask = nil
        hotelPriceTask = nil
        cachedInbound = []
        cachedHotels = nil
        activeSignature = signature
    }

    private func startHotelPriceCheck(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) {
        guard hotelPriceTask == nil, cachedHotels == nil else { return }
        hotelPriceTask = Task { @MainActor [trip, makkahHotel, madinahHotel] in
            await self.hotelPriceService.search(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel
            )
        }
    }

    private func startInboundPrewarm(trip: TripDraft) {
        guard inboundPrewarmTask == nil, cachedInbound.isEmpty else { return }
        let request = makeInboundRequest(trip)
        let dates = FlightDatePlanner.dates(anchor: trip.returnDate, flexibility: trip.flexibility)
        inboundPrewarmTask = Task { @MainActor [request, dates] in
            do {
                let values = try await self.flightProvider.search(request: request, dates: dates) { partial in
                    self.cachedInbound = self.merge(self.cachedInbound, partial)
                }
                self.cachedInbound = self.merge(self.cachedInbound, values)
                return self.cachedInbound
            } catch {
                return self.cachedInbound
            }
        }
    }

    private func offer(from candidate: LiveFlightCandidate) -> FlightOffer? {
        guard accept(candidate) else { return nil }
        let value = FlightOffer(
            id: "fare:\(candidate.id)",
            direction: candidate.direction,
            airline: candidate.airline,
            flightNumber: candidate.flightNumber,
            origin: candidate.origin,
            destination: candidate.destination,
            departureAt: candidate.departureAt,
            arrivalAt: candidate.arrivalAt,
            stops: candidate.stops,
            durationMinutes: candidate.durationMinutes,
            totalPackagePrice: candidate.observedFare,
            currency: candidate.observedCurrency,
            sourceLabel: candidate.sourceName,
            packageTotalPrice: nil,
            quoteId: nil,
            sourceCandidateID: candidate.id,
            airlineCode: candidate.airlineCode,
            segments: candidate.segments,
            connectionAirports: candidate.connectionAirports,
            fareAmount: candidate.observedFare,
            fareScope: candidate.fareScope,
            fareObservedAt: candidate.observedAt,
            fareSourceURL: candidate.sourceURL,
            providerItineraryID: candidate.providerItineraryID,
            cabinClass: candidate.cabinClass,
            baggage: candidate.baggage,
            requiresSelfTransfer: candidate.requiresSelfTransfer
        )
        return value.isVerifiedForBooking ? value : nil
    }

    private func accept(_ candidate: LiveFlightCandidate) -> Bool {
        candidate.isDisplayableCandidate
    }

    private func merge(_ lhs: [LiveFlightCandidate], _ rhs: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var result = lhs.filter(accept)
        var indexByKey = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.deduplicationKey, $0.offset) })
        for candidate in rhs where accept(candidate) {
            if let index = indexByKey[candidate.deduplicationKey] {
                if candidate.observedAt > result[index].observedAt { result[index] = candidate }
            } else {
                indexByKey[candidate.deduplicationKey] = result.count
                result.append(candidate)
            }
        }
        return result
    }

    private func ranked(_ offers: [FlightOffer], anchor: Date) -> [FlightOffer] {
        offers.sorted { lhs, rhs in
            let lo = abs(dayOffset(lhs.departureAt, from: anchor))
            let ro = abs(dayOffset(rhs.departureAt, from: anchor))
            if lo != ro { return lo < ro }
            // Within the same calendar distance prefer simpler itineraries first,
            // then price, duration and departure time. This keeps direct flights
            // ahead of cheaper but materially more complex connections.
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            if lhs.currency == rhs.currency, lhs.totalPackagePrice != rhs.totalPackagePrice {
                return lhs.totalPackagePrice < rhs.totalPackagePrice
            }
            if lhs.durationMinutes != rhs.durationMinutes { return lhs.durationMinutes < rhs.durationMinutes }
            return lhs.departureAt < rhs.departureAt
        }
    }

    private func dayOffset(_ date: Date, from anchor: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: anchor),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }

    private func makeOutboundRequest(_ trip: TripDraft) -> FlightSearchRequest {
        FlightSearchRequest(
            direction: .outbound,
            origin: trip.originCode,
            destination: trip.outboundDestinationCode,
            date: trip.departureDate,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants,
            cabin: trip.effectiveFlightFilters.cabinClass.rawValue,
            filters: trip.effectiveFlightFilters
        )
    }

    private func makeInboundRequest(_ trip: TripDraft) -> FlightSearchRequest {
        FlightSearchRequest(
            direction: .inbound,
            origin: trip.returnOriginCode,
            destination: trip.originCode,
            date: trip.returnDate,
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
            trip.originCode,
            trip.outboundDestinationCode,
            trip.returnOriginCode,
            formatter.string(from: trip.departureDate),
            formatter.string(from: trip.returnDate),
            trip.flexibility.rawValue,
            String(trip.adults),
            String(trip.children),
            String(trip.infants),
            String(trip.rooms),
            filters.cabinClass.rawValue,
            filters.stops.rawValue,
            String(filters.minCarryOnBags),
            String(filters.minCheckedBags),
            filters.maxPriceUSD.map(String.init) ?? "-",
            filters.departureWindow.rawValue,
            filters.arrivalWindow.rawValue,
            filters.normalizedAirlinesInclude.joined(separator: ","),
            filters.normalizedAirlinesExclude.joined(separator: ","),
            filters.allowSelfTransfer ? "self-transfer" : "protected",
            filters.infantSeating.rawValue
        ].joined(separator: "|")
    }
}

@MainActor
final class AutomaticFlightSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let coordinator: RealFlightPackageSearchService

    init() {
        self.coordinator = RealFlightPackageSearchService()
    }

    init(flightProvider: FlightInventoryProviding) {
        self.coordinator = RealFlightPackageSearchService(flightProvider: flightProvider)
    }

    var currentHotelPriceSnapshot: HotelPriceSearchSnapshot? { coordinator.currentHotelPriceSnapshot }

    func ensureHotelPrices(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        madinahRoomId: String?,
        madinahRoomName: String?,
        forceRefresh: Bool
    ) async -> HotelPriceSearchSnapshot {
        await coordinator.ensureHotelPrices(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName,
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
        try await coordinator.searchOutboundProgressive(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            onUpdate: onUpdate
        )
    }

    func searchReturnProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: FlightOffer,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        try await coordinator.searchReturnProgressive(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            outbound: outbound,
            onUpdate: onUpdate
        )
    }
}
