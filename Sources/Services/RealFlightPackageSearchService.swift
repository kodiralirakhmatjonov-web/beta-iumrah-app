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

/// Production coordinator for independent one-way flight legs.
///
/// A round trip is intentionally built as two independent provider searches:
/// 1. origin -> Saudi Arabia (outbound)
/// 2. Saudi Arabia -> origin (return)
///
/// Each Ignav result keeps its own one-way fare. The UI never pairs two legs behind
/// the pilgrim's back and never treats a complete round-trip fare as a one-way fare.
@MainActor
final class RealFlightPackageSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let flightProvider: FlightInventoryProviding
    private let hotelCatalogService: HotelCatalogServicing

    private var activeSignature: String?
    private var cachedOutboundJourneys: [LiveFlightJourneyCandidate] = []
    private var cachedReturnJourneys: [LiveFlightJourneyCandidate] = []
    private var cachedHotels: HotelPriceSearchSnapshot?

    init() {
        self.flightProvider = IgnavFlightInventoryProvider()
        self.hotelCatalogService = HotelCatalogService()
    }

    init(flightProvider: FlightInventoryProviding, hotelCatalogService: HotelCatalogServicing) {
        self.flightProvider = flightProvider
        self.hotelCatalogService = hotelCatalogService
    }

    init(flightProvider: FlightInventoryProviding) {
        self.flightProvider = flightProvider
        self.hotelCatalogService = HotelCatalogService()
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
        _ = makkahHotel
        _ = madinahHotel
        prepareForOutbound(trip)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .starting))
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))

        let request = makeOneWayRequest(
            origin: trip.originCode,
            destination: trip.outboundDestinationCode,
            trip: trip
        )
        let dates = oneWayDatePairs(anchor: trip.departureDate, flexibility: trip.flexibility)

        do {
            var live = cachedOutboundJourneys
            let final = try await flightProvider.searchJourney(request: request, datePairs: dates) { values in
                live = self.mergeJourneys(live, values)
                self.cachedOutboundJourneys = live
                let offers = self.ranked(
                    self.offers(from: live, direction: .outbound),
                    anchor: trip.departureDate
                )
                onUpdate(.init(
                    discoveredCandidates: live.map(\.outbound),
                    pricedOffers: offers,
                    isSearching: true,
                    status: offers.isEmpty ? .checkingAirlines : .comparingFares
                ))
            }
            live = mergeJourneys(live, final)
            cachedOutboundJourneys = live
            let offers = ranked(offers(from: live, direction: .outbound), anchor: trip.departureDate)
            onUpdate(.init(
                discoveredCandidates: live.map(\.outbound),
                pricedOffers: offers,
                isSearching: false,
                status: .continuing
            ))
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
        guard trip.isRoundTripFlight, outbound.isVerifiedForBooking else {
            throw FlightEngineAvailabilityError.realOutboundRequired
        }
        prepareForReturn(trip)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .starting))
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))

        let request = makeOneWayRequest(
            origin: trip.returnOriginCode,
            destination: trip.originCode,
            trip: trip
        )
        let dates = oneWayDatePairs(anchor: trip.returnDate, flexibility: trip.flexibility)

        do {
            var live = cachedReturnJourneys
            let final = try await flightProvider.searchJourney(request: request, datePairs: dates) { values in
                live = self.mergeJourneys(live, values)
                self.cachedReturnJourneys = live
                let offers = self.ranked(
                    self.offers(from: live, direction: .inbound),
                    anchor: trip.returnDate
                )
                onUpdate(.init(
                    discoveredCandidates: live.map { self.candidate($0.outbound, direction: .inbound) },
                    pricedOffers: offers,
                    isSearching: true,
                    status: offers.isEmpty ? .checkingAirlines : .comparingFares
                ))
            }
            live = mergeJourneys(live, final)
            cachedReturnJourneys = live
            let offers = ranked(offers(from: live, direction: .inbound), anchor: trip.returnDate)
            onUpdate(.init(
                discoveredCandidates: live.map { candidate($0.outbound, direction: .inbound) },
                pricedOffers: offers,
                isSearching: false,
                status: .continuing
            ))
            if offers.isEmpty { throw FlightEngineAvailabilityError.noVerifiedFlights }
            return offers
        } catch FlightInventoryProviderError.notConfigured {
            onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: false, status: nil))
            throw FlightEngineAvailabilityError.flightProviderNotConfigured
        }
    }

    /// Converts the server-maintained 48-hour hotel catalog cache into the same
    /// normalized pricing snapshot consumed by the local package engine. Beta never
    /// opens Booking/Expedia and never scrapes hotel prices on-device.
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
        _ = makkahRoomCapacity
        _ = madinahRoomCapacity
        if !forceRefresh, let cachedHotels, isCompleteHotelSnapshot(cachedHotels, trip: trip) {
            return cachedHotels
        }
        if forceRefresh { cachedHotels = nil }

        let windows = TripStayPlanner.windows(for: trip, calendar: Calendar(identifier: .gregorian))
        let makkahPrice = await catalogPrice(for: makkahHotel, forceRefresh: forceRefresh)
        let madinahPrice = await catalogPrice(
            for: trip.scope == .makkahAndMadinah ? madinahHotel : nil,
            forceRefresh: forceRefresh
        )

        let makkahObservation = makeCatalogObservation(
            hotel: makkahHotel,
            city: "Makkah",
            window: windows.makkah,
            roomID: makkahRoomId,
            roomName: makkahRoomName,
            price: makkahPrice
        )

        let madinahObservation: HotelPriceObservation?
        if trip.scope == .makkahAndMadinah, let madinahHotel, let window = windows.madinah {
            madinahObservation = makeCatalogObservation(
                hotel: madinahHotel,
                city: "Madinah",
                window: window,
                roomID: madinahRoomId,
                roomName: madinahRoomName,
                price: madinahPrice
            )
        } else {
            madinahObservation = nil
        }

        let snapshot = HotelPriceSearchSnapshot(
            makkah: makkahObservation.map { [$0] } ?? [],
            madinah: madinahObservation.map { [$0] } ?? []
        )
        if isCompleteHotelSnapshot(snapshot, trip: trip) { cachedHotels = snapshot }
        return snapshot
    }

    private func catalogPrice(for hotel: HotelSummary?, forceRefresh: Bool) async -> HotelCatalogPrice? {
        guard let hotel else { return nil }
        return await catalogPrice(for: hotel, forceRefresh: forceRefresh)
    }

    private func catalogPrice(for hotel: HotelSummary, forceRefresh: Bool) async -> HotelCatalogPrice? {
        if !forceRefresh, let price = hotel.price, price.isFresh { return price }
        do {
            let detail = try await hotelCatalogService.hotelDetail(id: hotel.id)
            guard let price = detail.price, price.isFresh else { return nil }
            return price
        } catch {
            return nil
        }
    }

    private func makeCatalogObservation(
        hotel: HotelSummary,
        city: String,
        window: TripStayWindow,
        roomID: String?,
        roomName: String?,
        price: HotelCatalogPrice?
    ) -> HotelPriceObservation? {
        guard let price, price.isFresh,
              let amount = price.nightlyUSD, amount.isFinite, amount > 0,
              let fetchedAt = price.fetchedAt, let expiresAt = price.expiresAt else { return nil }

        let provider: HotelPriceProviderID
        let sourceURL: String
        switch price.provider?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "booking", "booking.com":
            provider = .booking
            sourceURL = "https://www.booking.com"
        case "expedia", "expedia.com":
            provider = .expedia
            sourceURL = "https://www.expedia.com"
        default:
            return nil
        }

        return HotelPriceObservation(
            id: "catalog-\(hotel.id)-\(fetchedAt)",
            hotelId: hotel.id,
            hotelName: hotel.name,
            city: city,
            amount: Decimal(amount),
            currency: "USD",
            unit: .perRoomNight,
            providerId: provider,
            providerName: "\(price.providerDisplayName) · iumrah 48h cache",
            observedAt: fetchedAt,
            expiresAt: expiresAt,
            checkInDate: Self.catalogDay.string(from: window.checkIn),
            checkOutDate: Self.catalogDay.string(from: window.checkOut),
            sourceURL: sourceURL,
            roomId: roomID,
            roomName: roomName
        )
    }

    private static let catalogDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func isCompleteHotelSnapshot(_ snapshot: HotelPriceSearchSnapshot, trip: TripDraft) -> Bool {
        !snapshot.makkah.isEmpty && (trip.scope != .makkahAndMadinah || !snapshot.madinah.isEmpty)
    }

    func invalidateHotelPrices() {
        cachedHotels = nil
    }

    func invalidateFlightInventory() {
        activeSignature = nil
        cachedOutboundJourneys = []
        cachedReturnJourneys = []
    }

    func invalidateSession() {
        activeSignature = nil
        cachedOutboundJourneys = []
        cachedReturnJourneys = []
        cachedHotels = nil
    }

    private func prepareForOutbound(_ trip: TripDraft) {
        let signature = makeSignature(trip)
        guard activeSignature != signature else { return }
        activeSignature = signature
        cachedOutboundJourneys = []
        cachedReturnJourneys = []
        cachedHotels = nil
    }

    private func prepareForReturn(_ trip: TripDraft) {
        let signature = makeSignature(trip)
        guard activeSignature != signature else { return }
        activeSignature = signature
        cachedOutboundJourneys = []
        cachedReturnJourneys = []
        cachedHotels = nil
    }

    /// Converts every valid provider result into a visible fare row. Only exact
    /// duplicate result rows are collapsed; distinct Ignav fare variants remain
    /// visible even when they use the same physical flight or provider itinerary ID.
    private func offers(from journeys: [LiveFlightJourneyCandidate], direction: FlightDirection) -> [FlightOffer] {
        var seenResults = Set<String>()
        var values: [FlightOffer] = []
        for journey in journeys where journey.isDisplayableCandidate {
            guard seenResults.insert(journeyResultKey(journey)).inserted,
                  let value = offer(from: journey, direction: direction) else { continue }
            values.append(value)
        }
        return values
    }

    private func offer(from journey: LiveFlightJourneyCandidate, direction: FlightDirection) -> FlightOffer? {
        guard journey.isDisplayableCandidate else { return nil }
        let source = journey.outbound
        let resultKey = journeyResultKey(journey)
        let value = FlightOffer(
            id: "fare:\(direction.rawValue):\(resultKey)",
            direction: direction,
            airline: source.airline,
            flightNumber: source.flightNumber,
            origin: source.origin,
            destination: source.destination,
            departureAt: source.departureAt,
            arrivalAt: source.arrivalAt,
            stops: source.stops,
            durationMinutes: source.durationMinutes,
            totalPackagePrice: journey.totalFare,
            currency: journey.currency,
            sourceLabel: journey.sourceName,
            packageTotalPrice: nil,
            quoteId: nil,
            sourceCandidateID: source.id,
            airlineCode: source.airlineCode,
            segments: source.segments,
            connectionAirports: source.connectionAirports,
            fareAmount: journey.totalFare,
            fareScope: journey.fareScope,
            fareObservedAt: journey.observedAt,
            fareSourceURL: source.sourceURL,
            providerItineraryID: journey.providerItineraryID,
            cabinClass: source.cabinClass,
            baggage: journey.baggage ?? source.baggage,
            requiresSelfTransfer: journey.requiresSelfTransfer ?? source.requiresSelfTransfer,
            pairedLeg: nil
        )
        return value.isVerifiedForBooking ? value : nil
    }

    private func candidate(_ source: LiveFlightCandidate, direction: FlightDirection) -> LiveFlightCandidate {
        LiveFlightCandidate(
            id: "\(source.id):\(direction.rawValue)",
            sourceID: source.sourceID,
            sourceName: source.sourceName,
            direction: direction,
            airline: source.airline,
            flightNumber: source.flightNumber,
            origin: source.origin,
            destination: source.destination,
            departureAt: source.departureAt,
            arrivalAt: source.arrivalAt,
            stops: source.stops,
            durationMinutes: source.durationMinutes,
            observedFare: source.observedFare,
            observedCurrency: source.observedCurrency,
            fareScope: source.fareScope,
            observedAt: source.observedAt,
            sourceURL: source.sourceURL,
            rawFingerprint: source.rawFingerprint,
            airlineCode: source.airlineCode,
            segments: source.segments,
            connectionAirports: source.connectionAirports,
            providerItineraryID: source.providerItineraryID,
            cabinClass: source.cabinClass,
            baggage: source.baggage,
            requiresSelfTransfer: source.requiresSelfTransfer
        )
    }

    private func mergeJourneys(_ lhs: [LiveFlightJourneyCandidate], _ rhs: [LiveFlightJourneyCandidate]) -> [LiveFlightJourneyCandidate] {
        var values = lhs.filter(\.isDisplayableCandidate)
        var keys = Set(values.map { journeyResultKey($0) })
        for journey in rhs where journey.isDisplayableCandidate && keys.insert(journeyResultKey(journey)).inserted {
            values.append(journey)
        }
        return values
    }

    /// Exact duplicate rows are collapsed, but distinct fares returned by Ignav are
    /// preserved even when Ignav reuses the same itinerary identifier.
    private func journeyResultKey(_ journey: LiveFlightJourneyCandidate) -> String {
        let fare = NSDecimalNumber(decimal: journey.totalFare).stringValue
        let departure = Int(journey.outbound.departureAt.timeIntervalSince1970)
        let arrival = Int(journey.outbound.arrivalAt.timeIntervalSince1970)
        let baggage = "\(journey.baggage?.carryOn ?? -1):\(journey.baggage?.checked ?? -1)"
        let transfer = journey.requiresSelfTransfer.map { $0 ? "self" : "protected" } ?? "unknown"
        return [journey.providerItineraryID, fare, journey.currency.uppercased(), String(departure), String(arrival), baggage, transfer]
            .joined(separator: "|")
            .lowercased()
    }

    private func ranked(_ offers: [FlightOffer], anchor: Date) -> [FlightOffer] {
        offers.sorted { lhs, rhs in
            let lo = abs(dayOffset(lhs.departureAt, from: anchor))
            let ro = abs(dayOffset(rhs.departureAt, from: anchor))
            if lo != ro { return lo < ro }
            if lhs.currency == rhs.currency, lhs.totalPackagePrice != rhs.totalPackagePrice {
                return lhs.totalPackagePrice < rhs.totalPackagePrice
            }
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            if lhs.durationMinutes != rhs.durationMinutes { return lhs.durationMinutes < rhs.durationMinutes }
            return lhs.departureAt < rhs.departureAt
        }
    }

    private func oneWayDatePairs(anchor: Date, flexibility: DateFlexibility) -> [FlightJourneyDatePair] {
        FlightDatePlanner.dates(
            anchor: anchor,
            flexibility: flexibility,
            calendar: Calendar.current
        ).map { FlightJourneyDatePair(outbound: $0, inbound: nil) }
    }

    private func dayOffset(_ date: Date, from anchor: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: anchor),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }

    private func makeOneWayRequest(origin: String, destination: String, trip: TripDraft) -> FlightJourneySearchRequest {
        FlightJourneySearchRequest(
            outboundOrigin: origin,
            outboundDestination: destination,
            inboundOrigin: nil,
            inboundDestination: nil,
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
            trip.originCode, trip.outboundDestinationCode, trip.isRoundTripFlight ? trip.returnOriginCode : "-",
            trip.resolvedFlightTripType.rawValue,
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
