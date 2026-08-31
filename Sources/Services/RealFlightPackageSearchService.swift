import Foundation

enum FlightEngineAvailabilityError: LocalizedError {
    case realOutboundRequired
    case noVerifiedFlights

    var errorDescription: String? {
        switch self {
        case .realOutboundRequired:
            return "Обратный поиск требует реальный выбранный рейс туда. Повторите поиск перелёта."
        case .noVerifiedFlights:
            return "Пока не удалось получить подтверждённые рейсы. Повторите поиск — найденные источники будут проверены заново."
        }
    }
}

/// Generator V2 flight discovery. Package pricing is deliberately NOT performed
/// here. Server HTTP bots and the device WebKit bots only produce verified fare
/// components; the existing package formula is applied locally after selection.
@MainActor
final class RealFlightPackageSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let packageEngine = RemotePackageEngineClient()
    private let hotelPriceService = HotelLivePriceSearchService()

    private var activeSignature: String?
    private var cachedInbound: [LiveFlightCandidate] = []
    private var cachedHotels: HotelPriceSearchSnapshot?
    private var inboundPrewarmTask: Task<[LiveFlightCandidate], Never>?
    private var hotelPriceTask: Task<HotelPriceSearchSnapshot, Never>?

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
        prepare(for: trip)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .starting))

        startHotelPriceCheck(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingHotels))
        startInboundServerPrewarm(trip: trip)

        let request = makeOutboundRequest(trip)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))
        let deviceTask = Task { @MainActor [request] in
            await self.deviceCandidates(
                request: request,
                flexibility: trip.flexibility,
                onProgress: { candidates in
                    let offers = candidates.compactMap(self.offer(from:))
                    onUpdate(.init(
                        discoveredCandidates: candidates,
                        pricedOffers: offers,
                        isSearching: true,
                        status: .checkingAirlines
                    ))
                }
            )
        }

        var serverCandidates: [LiveFlightCandidate] = []
        let serverValues = await serverCandidatesProgressive(
            request: request,
            flexibility: trip.flexibility,
            onProvider: { provider in
                onUpdate(.init(
                    discoveredCandidates: serverCandidates,
                    pricedOffers: serverCandidates.compactMap(self.offer(from:)),
                    isSearching: true,
                    status: .checkingProvider(provider.displayName)
                ))
            },
            onCandidates: { values in
                serverCandidates = self.merge(serverCandidates, values)
                onUpdate(.init(
                    discoveredCandidates: serverCandidates,
                    pricedOffers: serverCandidates.compactMap(self.offer(from:)),
                    isSearching: true,
                    status: .comparingFares
                ))
            }
        )
        serverCandidates = merge(serverCandidates, serverValues)

        let deviceValues = await deviceTask.value
        let combined = merge(serverCandidates, deviceValues)
        let offers = ranked(combined.compactMap(offer(from:)), anchor: trip.departureDate)
        onUpdate(.init(discoveredCandidates: combined, pricedOffers: offers, isSearching: false, status: .continuing))
        if offers.isEmpty { throw FlightEngineAvailabilityError.noVerifiedFlights }
        return offers
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

        if let prewarm = inboundPrewarmTask {
            cachedInbound = merge(cachedInbound, await prewarm.value)
            inboundPrewarmTask = nil
        }
        if !cachedInbound.isEmpty {
            let first = ranked(cachedInbound.compactMap(offer(from:)), anchor: trip.returnDate)
            onUpdate(.init(discoveredCandidates: cachedInbound, pricedOffers: first, isSearching: true, status: .continuing))
        } else {
            onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))
        }

        let request = makeInboundRequest(trip)
        let device = await deviceCandidates(
            request: request,
            flexibility: trip.flexibility,
            onProgress: { values in
                self.cachedInbound = self.merge(self.cachedInbound, values)
                onUpdate(.init(
                    discoveredCandidates: self.cachedInbound,
                    pricedOffers: self.ranked(self.cachedInbound.compactMap(self.offer(from:)), anchor: trip.returnDate),
                    isSearching: true,
                    status: .checkingAirlines
                ))
            }
        )
        cachedInbound = merge(cachedInbound, device)

        // A second server pass is cheap because successful provider/date responses
        // are cached in D1. It also picks up providers that finished after prewarm.
        let server = await serverCandidatesProgressive(
            request: request,
            flexibility: trip.flexibility,
            onProvider: { provider in
                onUpdate(.init(
                    discoveredCandidates: self.cachedInbound,
                    pricedOffers: self.ranked(self.cachedInbound.compactMap(self.offer(from:)), anchor: trip.returnDate),
                    isSearching: true,
                    status: .checkingProvider(provider.displayName)
                ))
            },
            onCandidates: { values in
                self.cachedInbound = self.merge(self.cachedInbound, values)
                onUpdate(.init(
                    discoveredCandidates: self.cachedInbound,
                    pricedOffers: self.ranked(self.cachedInbound.compactMap(self.offer(from:)), anchor: trip.returnDate),
                    isSearching: true,
                    status: .comparingFares
                ))
            }
        )
        cachedInbound = merge(cachedInbound, server)
        let final = ranked(cachedInbound.compactMap(offer(from:)), anchor: trip.returnDate)
        onUpdate(.init(discoveredCandidates: cachedInbound, pricedOffers: final, isSearching: false, status: .continuing))
        if final.isEmpty { throw FlightEngineAvailabilityError.noVerifiedFlights }
        return final
    }

    func ensureHotelPrices(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async -> HotelPriceSearchSnapshot {
        prepare(for: trip)
        if let cachedHotels, cachedHotels.hasLiveRates { return cachedHotels }
        if let hotelPriceTask {
            let value = await hotelPriceTask.value
            cachedHotels = value
            self.hotelPriceTask = nil
            return value
        }
        let value = await hotelPriceService.search(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        cachedHotels = value
        return value
    }

    func invalidateSession() {
        activeSignature = nil
        cachedInbound = []
        cachedHotels = nil
        inboundPrewarmTask?.cancel()
        hotelPriceTask?.cancel()
        inboundPrewarmTask = nil
        hotelPriceTask = nil
    }

    private func prepare(for trip: TripDraft) {
        let signature = makeSignature(trip)
        guard signature != activeSignature else { return }
        invalidateSession()
        activeSignature = signature
    }

    private func startHotelPriceCheck(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) {
        guard hotelPriceTask == nil, cachedHotels == nil else { return }
        hotelPriceTask = Task { @MainActor in
            // Let the first airline WebView/server request start first. The hotel
            // verification still runs while the pilgrim compares flight options.
            try? await Task.sleep(for: .milliseconds(900))
            let value = await self.hotelPriceService.search(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
            self.cachedHotels = value
            return value
        }
    }

    private func startInboundServerPrewarm(trip: TripDraft) {
        guard inboundPrewarmTask == nil, cachedInbound.isEmpty else { return }
        let request = makeInboundRequest(trip)
        inboundPrewarmTask = Task { @MainActor in
            await self.serverCandidatesProgressive(request: request, flexibility: trip.flexibility, onProvider: { _ in }, onCandidates: { _ in })
        }
    }

    private func deviceCandidates(
        request: FlightBotSearchRequest,
        flexibility: DateFlexibility,
        onProgress: @escaping @MainActor ([LiveFlightCandidate]) -> Void
    ) async -> [LiveFlightCandidate] {
        do {
            let result = try await FlightBotOrchestrator.shared.search(
                request: request,
                flexibility: flexibility,
                requirement: .displayable,
                minimumResults: 1,
                preferredResults: AppConfig.flightBotPreferredOptions,
                onProgress: { candidates in onProgress(candidates.filter(self.accept)) }
            )
            return result.candidates.filter(accept)
        } catch {
            return []
        }
    }

    private func serverCandidatesProgressive(
        request: FlightBotSearchRequest,
        flexibility: DateFlexibility,
        onProvider: @escaping @MainActor (FlightBotProvider) -> Void,
        onCandidates: @escaping @MainActor ([LiveFlightCandidate]) -> Void
    ) async -> [LiveFlightCandidate] {
        let providers = Array(FlightBotProviderRegistry.ordered(for: request.origin, destination: request.destination).prefix(4))
        guard !providers.isEmpty else { return [] }
        let dates = FlightDatePlanner.dates(anchor: request.date, flexibility: flexibility)
        var output: [LiveFlightCandidate] = []

        for (dateIndex, date) in dates.enumerated() {
            if output.count >= AppConfig.flightBotPreferredOptions { return output }
            let providersForDate = dateIndex == 0 ? providers : Array(providers.prefix(2))
            let offset = dayOffset(date, from: request.date)
            for provider in providersForDate {
                if Task.isCancelled || output.count >= AppConfig.flightBotPreferredOptions { return output }
                onProvider(provider)
                let dated = FlightBotSearchRequest(
                    direction: request.direction,
                    origin: request.origin,
                    destination: request.destination,
                    date: date,
                    adults: request.adults,
                    children: request.children,
                    infants: request.infants,
                    cabin: request.cabin
                )
                do {
                    let response = try await packageEngine.searchFlightProvider(providerID: provider.id, request: dated, dateOffset: offset)
                    let values = response.candidates.compactMap { $0.liveCandidate() }.filter(accept)
                    if !values.isEmpty {
                        output = merge(output, values)
                        onCandidates(values)
                    }
                } catch {
                    // Provider failure is isolated. Device WebKit and all other
                    // server providers continue without turning the screen into an error.
                }
            }
        }
        return output
    }

    private func offer(from candidate: LiveFlightCandidate) -> FlightOffer? {
        guard accept(candidate) else { return nil }
        let normalizedSegments = candidate.segments ?? []
        let connections = candidate.connectionAirports
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
            currency: candidate.observedCurrency.uppercased(),
            sourceLabel: candidate.providerName,
            packageTotalPrice: nil,
            quoteId: nil,
            sourceCandidateID: candidate.id,
            airlineCode: candidate.airlineCode,
            segments: normalizedSegments,
            connectionAirports: connections,
            fareAmount: candidate.observedFare,
            fareScope: candidate.fareScope,
            fareObservedAt: candidate.observedAt,
            fareSourceURL: candidate.sourceURL
        )
        return value.isVerifiedForBooking ? value : nil
    }

    private func accept(_ candidate: LiveFlightCandidate) -> Bool {
        candidate.isDisplayableCandidate &&
        candidate.observedFare > 0 &&
        candidate.fareScope != .unknown &&
        candidate.observedCurrency.range(of: "^[A-Za-z]{3}$", options: .regularExpression) != nil &&
        Date().timeIntervalSince(candidate.observedAt) < 60 * 60
    }

    private func merge(_ lhs: [LiveFlightCandidate], _ rhs: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var result = lhs.filter(accept)
        var indexByKey = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.deduplicationKey, $0.offset) })
        for candidate in rhs where accept(candidate) {
            if let index = indexByKey[candidate.deduplicationKey] {
                // Prefer a fresher fare; on a tie prefer the server-normalized USD
                // observation because local pricing can consume it immediately.
                let current = result[index]
                if candidate.observedAt > current.observedAt ||
                    (candidate.observedCurrency.uppercased() == "USD" && current.observedCurrency.uppercased() != "USD") {
                    result[index] = candidate
                }
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
            if lhs.currency == rhs.currency, lhs.totalPackagePrice != rhs.totalPackagePrice {
                return lhs.totalPackagePrice < rhs.totalPackagePrice
            }
            return lhs.departureAt < rhs.departureAt
        }
    }

    private func dayOffset(_ date: Date, from anchor: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor), to: calendar.startOfDay(for: date)).day ?? 0
    }

    private func makeOutboundRequest(_ trip: TripDraft) -> FlightBotSearchRequest {
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

    private func makeInboundRequest(_ trip: TripDraft) -> FlightBotSearchRequest {
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

    private func makeSignature(_ trip: TripDraft) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            trip.originCode,
            trip.outboundDestinationCode,
            trip.returnOriginCode,
            formatter.string(from: trip.departureDate),
            formatter.string(from: trip.returnDate),
            trip.flexibility.rawValue,
            String(trip.adults), String(trip.children), String(trip.infants), String(trip.rooms)
        ].joined(separator: "|")
    }
}

@MainActor
final class AutomaticFlightSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let real = RealFlightPackageSearchService()
    private let sandbox = BetaFlightSearchService()

    var currentHotelPriceSnapshot: HotelPriceSearchSnapshot? { real.currentHotelPriceSnapshot }

    func ensureHotelPrices(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async -> HotelPriceSearchSnapshot {
        await real.ensureHotelPrices(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
    }

    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        if AppConfig.usesSandboxFlightSearch { return try await sandbox.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel) }
        return try await real.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        if AppConfig.usesSandboxFlightSearch { return try await sandbox.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound) }
        return try await real.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
    }

    func searchOutboundProgressive(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, onUpdate: @escaping FlightSearchProgressHandler) async throws -> [FlightOffer] {
        if AppConfig.usesSandboxFlightSearch { return try await sandbox.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate) }
        return try await real.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate)
    }

    func searchReturnProgressive(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer, onUpdate: @escaping FlightSearchProgressHandler) async throws -> [FlightOffer] {
        if AppConfig.usesSandboxFlightSearch { return try await sandbox.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate) }
        return try await real.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate)
    }
}
