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
        // Device-only providers start immediately beside the server pass. Providers
        // that already have a server adapter are not duplicated in WebKit unless
        // that server adapter returns nothing.
        let deviceOnlyIDs = self.deviceOnlyProviderIDs(origin: request.origin, destination: request.destination)
        let deviceTask = Task { @MainActor [request, deviceOnlyIDs] in
            await self.deviceCandidates(
                request: request,
                flexibility: trip.flexibility,
                allowedProviderIDs: deviceOnlyIDs,
                onProvider: { provider in
                    onUpdate(.init(
                        discoveredCandidates: [],
                        pricedOffers: [],
                        isSearching: true,
                        status: .checkingProvider(provider.displayName)
                    ))
                },
                onProviderEvent: { event in
                    onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, providerEvents: [event]))
                },
                onProgress: { candidates in
                    let offers = candidates.compactMap(self.offer(from:))
                    onUpdate(.init(
                        discoveredCandidates: candidates,
                        pricedOffers: offers,
                        isSearching: true,
                        status: .comparingFares
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
            onProviderEvent: { event in
                onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, providerEvents: [event]))
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

        // True device fallback for a server-capable carrier: only launch it after
        // the server attempt produced no verified candidate for that carrier.
        let missingServerIDs = self.missingServerProviderIDs(
            origin: request.origin,
            destination: request.destination,
            candidates: serverCandidates
        )
        let serverSnapshot = serverCandidates
        let serverFallbackTask = Task { @MainActor [request, missingServerIDs, serverSnapshot] in
            guard !missingServerIDs.isEmpty else { return [LiveFlightCandidate]() }
            return await self.deviceCandidates(
                request: request,
                flexibility: trip.flexibility,
                allowedProviderIDs: missingServerIDs,
                maxProviderAttempts: trip.flexibility.isWeeklyDiscovery ? nil : missingServerIDs.count,
                onProvider: { provider in
                    onUpdate(.init(
                        discoveredCandidates: serverSnapshot,
                        pricedOffers: serverSnapshot.compactMap(self.offer(from:)),
                        isSearching: true,
                        status: .checkingProvider(provider.displayName)
                    ))
                },
                onProviderEvent: { event in
                    onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, providerEvents: [event]))
                },
                onProgress: { values in
                    let merged = self.merge(serverSnapshot, values)
                    onUpdate(.init(
                        discoveredCandidates: merged,
                        pricedOffers: merged.compactMap(self.offer(from:)),
                        isSearching: true,
                        status: .continuing
                    ))
                }
            )
        }

        let deviceValues = await deviceTask.value
        let serverFallback = await serverFallbackTask.value
        let combined = merge(merge(serverCandidates, deviceValues), serverFallback)
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
        // A flexible outbound choice can move the authoritative hotel dates while
        // the return route/date stays unchanged. Reverification starts immediately
        // without discarding a useful return-flight prewarm cache.
        startHotelPriceCheck(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)

        // Never make the pilgrim wait for a hidden prewarm job to finish before
        // seeing the return screen. If prewarm already found something, surface it
        // immediately. If it has not found anything yet, cancel it and switch to
        // the visible progressive search so provider status/results can stream.
        if let prewarm = inboundPrewarmTask {
            if cachedInbound.isEmpty {
                prewarm.cancel()
                inboundPrewarmTask = nil
            } else {
                let first = ranked(cachedInbound.compactMap(offer(from:)), anchor: trip.returnDate)
                onUpdate(.init(discoveredCandidates: cachedInbound, pricedOffers: first, isSearching: true, status: .continuing))
                cachedInbound = merge(cachedInbound, await prewarm.value)
                inboundPrewarmTask = nil
            }
        }

        if !cachedInbound.isEmpty {
            let first = ranked(cachedInbound.compactMap(offer(from:)), anchor: trip.returnDate)
            onUpdate(.init(discoveredCandidates: cachedInbound, pricedOffers: first, isSearching: true, status: .continuing))
        } else {
            onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, status: .checkingAirlines))
        }

        let request = makeInboundRequest(trip)
        let alreadyObserved = Set(cachedInbound.map(\.providerID))
        let deviceOnlyIDs = self.deviceOnlyProviderIDs(origin: request.origin, destination: request.destination)
            .subtracting(alreadyObserved)
        let deviceTask = Task { @MainActor [request, deviceOnlyIDs] in
            await self.deviceCandidates(
                request: request,
                flexibility: trip.flexibility,
                allowedProviderIDs: deviceOnlyIDs,
                onProvider: { provider in
                    onUpdate(.init(
                        discoveredCandidates: self.cachedInbound,
                        pricedOffers: self.ranked(self.cachedInbound.compactMap(self.offer(from:)), anchor: trip.returnDate),
                        isSearching: true,
                        status: .checkingProvider(provider.displayName)
                    ))
                },
                onProviderEvent: { event in
                    onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, providerEvents: [event]))
                },
                onProgress: { values in
                    self.cachedInbound = self.merge(self.cachedInbound, values)
                    onUpdate(.init(
                        discoveredCandidates: self.cachedInbound,
                        pricedOffers: self.ranked(self.cachedInbound.compactMap(self.offer(from:)), anchor: trip.returnDate),
                        isSearching: true,
                        status: .comparingFares
                    ))
                }
            )
        }

        // Server and device-only providers run beside each other. The server pass
        // is still authoritative for server-capable carriers, but it never blocks
        // Qanot/Centrum/Air Samarkand WebKit discovery.
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
            onProviderEvent: { event in
                onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, providerEvents: [event]))
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

        let missingServerIDs = self.missingServerProviderIDs(
            origin: request.origin,
            destination: request.destination,
            candidates: cachedInbound
        )
        let serverSnapshot = cachedInbound
        let serverFallbackTask = Task { @MainActor [request, missingServerIDs, serverSnapshot] in
            guard !missingServerIDs.isEmpty else { return [LiveFlightCandidate]() }
            return await self.deviceCandidates(
                request: request,
                flexibility: trip.flexibility,
                allowedProviderIDs: missingServerIDs,
                maxProviderAttempts: trip.flexibility.isWeeklyDiscovery ? nil : missingServerIDs.count,
                onProvider: { provider in
                    onUpdate(.init(
                        discoveredCandidates: serverSnapshot,
                        pricedOffers: self.ranked(serverSnapshot.compactMap(self.offer(from:)), anchor: trip.returnDate),
                        isSearching: true,
                        status: .checkingProvider(provider.displayName)
                    ))
                },
                onProviderEvent: { event in
                    onUpdate(.init(discoveredCandidates: [], pricedOffers: [], isSearching: true, providerEvents: [event]))
                },
                onProgress: { values in
                    let merged = self.merge(serverSnapshot, values)
                    onUpdate(.init(
                        discoveredCandidates: merged,
                        pricedOffers: self.ranked(merged.compactMap(self.offer(from:)), anchor: trip.returnDate),
                        isSearching: true,
                        status: .continuing
                    ))
                }
            )
        }

        let device = await deviceTask.value
        let serverFallback = await serverFallbackTask.value
        cachedInbound = merge(merge(cachedInbound, device), serverFallback)
        let final = ranked(cachedInbound.compactMap(offer(from:)), anchor: trip.returnDate)
        onUpdate(.init(discoveredCandidates: cachedInbound, pricedOffers: final, isSearching: false, status: .continuing))
        if final.isEmpty { throw FlightEngineAvailabilityError.noVerifiedFlights }
        return final
    }

    func resumeFlightChallenge(_ challenge: FlightBotChallenge) async -> [FlightOffer] {
        FlightBotDeviceSessionPool.shared.verificationCompleted(challenge)
        FlightBotChallengeCenter.shared.clear(challenge)
        FlightBotOrchestrator.shared.resetCheckpointsAfterVerification()

        guard let provider = FlightBotProviderRegistry.providers.first(where: { $0.id == challenge.providerID }),
              provider.supportsDeviceSearch,
              provider.acceptsSourceURL(challenge.url) else { return [] }

        do {
            let candidates = try await FlightBotRunner(
                provider: provider,
                request: challenge.request,
                requirement: .displayable
            ).run(timeoutSeconds: provider.deviceTimeoutSeconds)
            let verified = candidates.filter(accept)
            return ranked(verified.compactMap(offer(from:)), anchor: challenge.request.date)
        } catch FlightBotRunner.BotError.challengeRequired(let nextChallenge) {
            FlightBotChallengeCenter.shared.publish(nextChallenge)
            return []
        } catch {
            return []
        }
    }

    func ensureHotelPrices(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        madinahRoomId: String?,
        madinahRoomName: String?
    ) async -> HotelPriceSearchSnapshot {
        prepare(for: trip)
        let hasExactRoomRequest = makkahRoomId != nil || madinahRoomId != nil
        if !hasExactRoomRequest, let cachedHotels, cachedHotels.hasLiveRates { return cachedHotels }
        if !hasExactRoomRequest, let hotelPriceTask {
            let value = await hotelPriceTask.value
            cachedHotels = value
            self.hotelPriceTask = nil
            return value
        }
        let value = await hotelPriceService.search(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName
        )
        if !hasExactRoomRequest { cachedHotels = value }
        return value
    }

    func invalidateHotelPrices() {
        cachedHotels = nil
        hotelPriceTask?.cancel()
        hotelPriceTask = nil
    }

    func invalidateSession() {
        activeSignature = nil
        cachedInbound = []
        invalidateHotelPrices()
        inboundPrewarmTask?.cancel()
        inboundPrewarmTask = nil
        FlightBotChallengeCenter.shared.clear()
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
            // Hotel verification starts with flight discovery. It must not wait for
            // the flight UI because the final package needs the same authoritative dates.
            let value = await self.hotelPriceService.search(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
            self.cachedHotels = value
            return value
        }
    }

    private func startInboundServerPrewarm(trip: TripDraft) {
        guard inboundPrewarmTask == nil, cachedInbound.isEmpty else { return }
        let request = makeInboundRequest(trip)
        inboundPrewarmTask = Task { @MainActor in
            // Return prewarm mirrors the visible architecture: server-capable and
            // device-only airlines start together, not one after another. Every
            // verified candidate is persisted in-memory immediately for instant
            // presentation if the pilgrim opens Return early.
            let deviceOnlyIDs = self.deviceOnlyProviderIDs(origin: request.origin, destination: request.destination)
            let deviceTask = Task { @MainActor [request, deviceOnlyIDs] in
                await self.deviceCandidates(
                    request: request,
                    flexibility: trip.flexibility,
                    allowedProviderIDs: deviceOnlyIDs,
                    publishChallenges: false,
                    onProgress: { values in
                        self.cachedInbound = self.merge(self.cachedInbound, values)
                    }
                )
            }

            let server = await self.serverCandidatesProgressive(
                request: request,
                flexibility: trip.flexibility,
                onProvider: { _ in },
                onCandidates: { values in
                    self.cachedInbound = self.merge(self.cachedInbound, values)
                }
            )
            self.cachedInbound = self.merge(self.cachedInbound, server)

            let missingServerIDs = self.missingServerProviderIDs(
                origin: request.origin,
                destination: request.destination,
                candidates: self.cachedInbound
            )
            let fallback = await self.deviceCandidates(
                request: request,
                flexibility: trip.flexibility,
                allowedProviderIDs: missingServerIDs,
                maxProviderAttempts: trip.flexibility.isWeeklyDiscovery ? nil : missingServerIDs.count,
                publishChallenges: false,
                onProgress: { values in
                    self.cachedInbound = self.merge(self.cachedInbound, values)
                }
            )
            let device = await deviceTask.value
            self.cachedInbound = self.merge(self.merge(self.cachedInbound, device), fallback)
            return self.cachedInbound
        }
    }

    private func deviceCandidates(
        request: FlightBotSearchRequest,
        flexibility: DateFlexibility,
        allowedProviderIDs: Set<FlightBotProviderID>? = nil,
        maxProviderAttempts: Int? = nil,
        publishChallenges: Bool = true,
        onProvider: @escaping @MainActor (FlightBotProvider) -> Void = { _ in },
        onProviderEvent: @escaping @MainActor (FlightProviderSearchEvent) -> Void = { _ in },
        onProgress: @escaping @MainActor ([LiveFlightCandidate]) -> Void
    ) async -> [LiveFlightCandidate] {
        var progressive: [LiveFlightCandidate] = []
        do {
            let result = try await FlightBotOrchestrator.shared.search(
                request: request,
                flexibility: flexibility,
                requirement: .displayable,
                minimumResults: 1,
                preferredResults: AppConfig.flightBotPreferredOptions,
                maxProviderAttempts: maxProviderAttempts,
                allowedProviderIDs: allowedProviderIDs,
                publishChallenges: publishChallenges,
                onProvider: onProvider,
                onProviderEvent: onProviderEvent,
                onProgress: { candidates in
                    progressive = self.merge(progressive, candidates.filter(self.accept))
                    onProgress(progressive)
                }
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
        onProviderEvent: @escaping @MainActor (FlightProviderSearchEvent) -> Void = { _ in },
        onCandidates: @escaping @MainActor ([LiveFlightCandidate]) -> Void
    ) async -> [LiveFlightCandidate] {
        let providers = FlightBotProviderRegistry.serverProviders(for: request.origin, destination: request.destination)
        guard !providers.isEmpty else { return [] }
        let dates = FlightDatePlanner.dates(anchor: request.date, flexibility: flexibility)
        var output: [LiveFlightCandidate] = []

        for (dateIndex, date) in dates.enumerated() {
            if !flexibility.isWeeklyDiscovery && output.count >= AppConfig.flightBotPreferredOptions { return output }
            let providersForDate = dateIndex == 0 ? providers : Array(providers.prefix(2))
            let offset = dayOffset(date, from: request.date)
            for provider in providersForDate {
                if Task.isCancelled || (!flexibility.isWeeklyDiscovery && output.count >= AppConfig.flightBotPreferredOptions) { return output }
                onProvider(provider)
                onProviderEvent(FlightProviderSearchEvent(
                    providerID: provider.id,
                    providerName: provider.displayName,
                    execution: .server,
                    date: date,
                    outcome: .searching
                ))
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
                        onProviderEvent(FlightProviderSearchEvent(
                            providerID: provider.id, providerName: provider.displayName, execution: .server,
                            date: date, outcome: .verified(values.count)
                        ))
                    } else {
                        onProviderEvent(FlightProviderSearchEvent(
                            providerID: provider.id, providerName: provider.displayName, execution: .server,
                            date: date, outcome: response.providerError == nil ? .notConfirmed : .unavailable
                        ))
                    }
                } catch {
                    onProviderEvent(FlightProviderSearchEvent(
                        providerID: provider.id, providerName: provider.displayName, execution: .server,
                        date: date, outcome: .unavailable
                    ))
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
        let age = Date().timeIntervalSince(candidate.observedAt)
        return candidate.isDisplayableCandidate &&
        candidate.observedFare > 0 &&
        candidate.fareScope != .unknown &&
        candidate.observedCurrency.range(of: "^[A-Za-z]{3}$", options: .regularExpression) != nil &&
        age >= -5 * 60 && age <= 30 * 60
    }

    private func deviceOnlyProviderIDs(origin: String, destination: String) -> Set<FlightBotProviderID> {
        Set(FlightBotProviderRegistry.ordered(for: origin, destination: destination)
            .filter { $0.supportsDeviceSearch && !$0.supportsServerSearch }
            .map(\.id))
    }

    private func missingServerProviderIDs(
        origin: String,
        destination: String,
        candidates: [LiveFlightCandidate]
    ) -> Set<FlightBotProviderID> {
        let observed = Set(candidates.map(\.providerID))
        return Set(FlightBotProviderRegistry.serverProviders(for: origin, destination: destination)
            .filter { $0.supportsDeviceSearch && !observed.contains($0.id) }
            .map(\.id))
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
            // Return prewarm depends on the return route/date, passenger mix and
            // flexibility. Do not invalidate it merely because the pilgrim picked
            // an outbound flight on +1/-1 day.
            formatter.string(from: trip.returnDate),
            trip.flexibility.rawValue,
            String(trip.adults), String(trip.children), String(trip.infants), String(trip.rooms)
        ].joined(separator: "|")
    }
}

@MainActor
final class AutomaticFlightSearchService: FlightSearchServicing, GeneratorComponentProviding {
    private let real = RealFlightPackageSearchService()

    var currentHotelPriceSnapshot: HotelPriceSearchSnapshot? { real.currentHotelPriceSnapshot }

    func resumeFlightChallenge(_ challenge: FlightBotChallenge) async -> [FlightOffer] {
        await real.resumeFlightChallenge(challenge)
    }

    func ensureHotelPrices(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        madinahRoomId: String?,
        madinahRoomName: String?
    ) async -> HotelPriceSearchSnapshot {
        await real.ensureHotelPrices(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName
        )
    }

    func invalidateHotelPrices() {
        real.invalidateHotelPrices()
    }

    /// Clears all flight/hotel discovery state after the authoritative TripDraft changes.
    /// JourneyStore owns the trip lifecycle, while this facade owns the concrete
    /// RealFlightPackageSearchService instance, so reset requests must be forwarded here.
    func invalidateSession() {
        real.invalidateSession()
    }

    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        try await real.searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        try await real.searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
    }

    func searchOutboundProgressive(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, onUpdate: @escaping FlightSearchProgressHandler) async throws -> [FlightOffer] {
        try await real.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate)
    }

    func searchReturnProgressive(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer, onUpdate: @escaping FlightSearchProgressHandler) async throws -> [FlightOffer] {
        try await real.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate)
    }
}
