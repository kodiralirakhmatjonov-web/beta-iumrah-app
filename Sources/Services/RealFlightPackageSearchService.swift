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
    private let packageEngine = RemotePackageEngineClient()
    private let hotelPriceService = HotelLivePriceSearchService()

    private var verifiedSignature: String?
    private var activeSignature: String?
    private var outboundCandidatesByID: [String: LiveFlightCandidate] = [:]
    private var inboundCandidatesByID: [String: LiveFlightCandidate] = [:]
    private var cachedHotelPrices: HotelPriceSearchSnapshot?

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
        try await ensureBackendReady(for: trip)
        prepareCaches(for: trip)
        onUpdate(.emptySearching)

        let outboundRequest = makeOutboundRequest(trip)
        let inboundRequest = makeInboundRequest(trip)
        var discoveredOutbound: [LiveFlightCandidate] = []
        var pricedOffers: [FlightOffer] = []

        // Keep WKWebView discovery strictly serial on iPhone. The previous version
        // started outbound and return discovery together; on memory-constrained
        // devices WebKit could terminate one content process and the whole search
        // looked like an intermittent network failure. First surface an outbound
        // itinerary, then obtain one return reference needed for package pricing.
        let initialFlexibility: DateFlexibility = trip.flexibility.isFlexibleDayRange ? .exact : trip.flexibility
        let initial = await safeSearch(
            request: outboundRequest,
            flexibility: initialFlexibility,
            minimumResults: 1,
            preferredResults: 1,
            maxProviderAttempts: 6,
            onProgress: { candidates in
                discoveredOutbound = self.mergeCandidates(discoveredOutbound, candidates)
                self.cacheOutbound(discoveredOutbound)
                onUpdate(.init(discoveredCandidates: discoveredOutbound, pricedOffers: pricedOffers, isSearching: true))
            }
        )
        discoveredOutbound = mergeCandidates(discoveredOutbound, initial?.candidates ?? [])

        // If the selected day has nothing and the user explicitly allowed nearby
        // days, widen immediately instead of showing an error state.
        if discoveredOutbound.isEmpty, trip.flexibility.isFlexibleDayRange {
            let widened = await safeSearch(
                request: outboundRequest,
                flexibility: trip.flexibility,
                minimumResults: 1,
                preferredResults: 1,
                onProgress: { candidates in
                    discoveredOutbound = self.mergeCandidates(discoveredOutbound, candidates)
                    self.cacheOutbound(discoveredOutbound)
                    onUpdate(.init(discoveredCandidates: discoveredOutbound, pricedOffers: pricedOffers, isSearching: true))
                }
            )
            discoveredOutbound = mergeCandidates(discoveredOutbound, widened?.candidates ?? [])
        }
        cacheOutbound(discoveredOutbound)
        onUpdate(.init(discoveredCandidates: discoveredOutbound, pricedOffers: pricedOffers, isSearching: true))

        let inboundReference = await referenceInboundResult(request: inboundRequest, trip: trip)
        let inboundCandidates = inboundReference?.candidates.filter(\.isDisplayableCandidate) ?? []
        cacheInbound(inboundCandidates)

        // First price pass deliberately uses the already configured hotel rate.
        // It gets the first selectable card on screen without starting additional
        // hotel WKWebViews while the initial flight bots are active.
        if !discoveredOutbound.isEmpty, !inboundCandidates.isEmpty {
            pricedOffers = await quoteOutboundSafely(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                outbound: discoveredOutbound,
                inbound: inboundCandidates,
                hotelPrices: nil,
                previous: pricedOffers
            )
            onUpdate(.init(discoveredCandidates: discoveredOutbound, pricedOffers: pricedOffers, isSearching: true))
        }

        // Continue behind the visible list. Every completed airline/date batch is
        // surfaced immediately and, when possible, repriced before the next batch.
        let continuation = await safeSearch(
            request: outboundRequest,
            flexibility: trip.flexibility,
            minimumResults: 1,
            preferredResults: AppConfig.flightBotPreferredOptions,
            onProgress: { candidates in
                discoveredOutbound = self.mergeCandidates(discoveredOutbound, candidates)
                self.cacheOutbound(discoveredOutbound)
                if !inboundCandidates.isEmpty {
                    pricedOffers = await self.quoteOutboundSafely(
                        trip: trip,
                        makkahHotel: makkahHotel,
                        madinahHotel: madinahHotel,
                        outbound: discoveredOutbound,
                        inbound: inboundCandidates,
                        hotelPrices: self.cachedHotelPrices,
                        previous: pricedOffers
                    )
                }
                onUpdate(.init(discoveredCandidates: discoveredOutbound, pricedOffers: pricedOffers, isSearching: true))
            }
        )
        discoveredOutbound = mergeCandidates(discoveredOutbound, continuation?.candidates ?? [])
        cacheOutbound(discoveredOutbound)

        // Flight discovery gets priority over hotel scraping. After the visible
        // list has been expanded across official carriers/dates, query Booking/
        // Expedia serially and refresh the package prices. This keeps WebKit at
        // one active search surface at a time on smaller iPhones.
        if !discoveredOutbound.isEmpty {
            let liveHotelPrices = await hotelPriceService.search(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel
            )
            if liveHotelPrices.hasLiveRates {
                cachedHotelPrices = liveHotelPrices
                if !inboundCandidates.isEmpty {
                    pricedOffers = await quoteOutboundSafely(
                        trip: trip,
                        makkahHotel: makkahHotel,
                        madinahHotel: madinahHotel,
                        outbound: discoveredOutbound,
                        inbound: inboundCandidates,
                        hotelPrices: liveHotelPrices,
                        previous: pricedOffers
                    )
                    onUpdate(.init(discoveredCandidates: discoveredOutbound, pricedOffers: pricedOffers, isSearching: true))
                }
            }
        }


        if !discoveredOutbound.isEmpty, !inboundCandidates.isEmpty {
            pricedOffers = await quoteOutboundSafely(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                outbound: discoveredOutbound,
                inbound: inboundCandidates,
                hotelPrices: cachedHotelPrices,
                previous: pricedOffers
            )
        }

        let final = rankedOffers(pricedOffers, anchor: trip.departureDate, flexibility: trip.flexibility)
        onUpdate(.init(discoveredCandidates: discoveredOutbound, pricedOffers: final, isSearching: false))
        return final
    }

    func searchReturnProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: FlightOffer,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        try await ensureBackendReady(for: trip)
        prepareCaches(for: trip)
        guard let sourceID = outbound.sourceCandidateID,
              let selectedOutbound = outboundCandidatesByID[sourceID],
              selectedOutbound.isDisplayableCandidate else {
            throw FlightEngineAvailabilityError.realOutboundRequired
        }

        onUpdate(.emptySearching)
        let request = makeInboundRequest(trip)
        var discoveredInbound: [LiveFlightCandidate] = []
        var pricedOffers: [FlightOffer] = []

        let initialFlexibility: DateFlexibility = trip.flexibility.isFlexibleDayRange ? .exact : trip.flexibility
        let initial = await safeSearch(
            request: request,
            flexibility: initialFlexibility,
            minimumResults: 1,
            preferredResults: 1,
            maxProviderAttempts: 6,
            onProgress: { candidates in
                discoveredInbound = self.mergeCandidates(discoveredInbound, candidates)
                self.cacheInbound(discoveredInbound)
                onUpdate(.init(discoveredCandidates: discoveredInbound, pricedOffers: pricedOffers, isSearching: true))
            }
        )
        discoveredInbound = mergeCandidates(discoveredInbound, initial?.candidates ?? [])

        if discoveredInbound.isEmpty, trip.flexibility.isFlexibleDayRange {
            let widened = await safeSearch(
                request: request,
                flexibility: trip.flexibility,
                minimumResults: 1,
                preferredResults: 1,
                onProgress: { candidates in
                    discoveredInbound = self.mergeCandidates(discoveredInbound, candidates)
                    self.cacheInbound(discoveredInbound)
                    onUpdate(.init(discoveredCandidates: discoveredInbound, pricedOffers: pricedOffers, isSearching: true))
                }
            )
            discoveredInbound = mergeCandidates(discoveredInbound, widened?.candidates ?? [])
        }
        cacheInbound(discoveredInbound)

        if !discoveredInbound.isEmpty {
            pricedOffers = await quoteReturnSafely(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                selectedOutbound: selectedOutbound,
                inbound: discoveredInbound,
                hotelPrices: cachedHotelPrices,
                previous: pricedOffers
            )
            onUpdate(.init(discoveredCandidates: discoveredInbound, pricedOffers: pricedOffers, isSearching: true))
        }

        let continuation = await safeSearch(
            request: request,
            flexibility: trip.flexibility,
            minimumResults: 1,
            preferredResults: AppConfig.flightBotPreferredOptions,
            onProgress: { candidates in
                discoveredInbound = self.mergeCandidates(discoveredInbound, candidates)
                self.cacheInbound(discoveredInbound)
                pricedOffers = await self.quoteReturnSafely(
                    trip: trip,
                    makkahHotel: makkahHotel,
                    madinahHotel: madinahHotel,
                    selectedOutbound: selectedOutbound,
                    inbound: discoveredInbound,
                    hotelPrices: self.cachedHotelPrices,
                    previous: pricedOffers
                )
                onUpdate(.init(discoveredCandidates: discoveredInbound, pricedOffers: pricedOffers, isSearching: true))
            }
        )
        discoveredInbound = mergeCandidates(discoveredInbound, continuation?.candidates ?? [])
        cacheInbound(discoveredInbound)

        if !discoveredInbound.isEmpty {
            pricedOffers = await quoteReturnSafely(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                selectedOutbound: selectedOutbound,
                inbound: discoveredInbound,
                hotelPrices: cachedHotelPrices,
                previous: pricedOffers
            )
        }

        let final = rankedOffers(pricedOffers, anchor: trip.returnDate, flexibility: trip.flexibility)
        onUpdate(.init(discoveredCandidates: discoveredInbound, pricedOffers: final, isSearching: false))
        return final
    }

    func invalidateSession() {
        activeSignature = nil
        outboundCandidatesByID.removeAll()
        inboundCandidatesByID.removeAll()
        cachedHotelPrices = nil
    }

    private func referenceInboundResult(
        request: FlightBotSearchRequest,
        trip: TripDraft
    ) async -> FlightBotOrchestrator.SearchResult? {
        if let exact = await safeSearch(
            request: request,
            flexibility: .exact,
            minimumResults: 1,
            preferredResults: 1,
            maxProviderAttempts: 8,
            onProgress: nil
        ), !exact.candidates.isEmpty {
            return exact
        }
        guard trip.flexibility.isFlexibleDayRange else { return nil }
        return await safeSearch(
            request: request,
            flexibility: trip.flexibility,
            minimumResults: 1,
            preferredResults: 1,
            onProgress: nil
        )
    }

    private func safeSearch(
        request: FlightBotSearchRequest,
        flexibility: DateFlexibility,
        minimumResults: Int,
        preferredResults: Int,
        maxProviderAttempts: Int? = nil,
        onProgress: (@MainActor ([LiveFlightCandidate]) async -> Void)?
    ) async -> FlightBotOrchestrator.SearchResult? {
        do {
            return try await FlightBotOrchestrator.shared.search(
                request: request,
                flexibility: flexibility,
                requirement: .displayable,
                minimumResults: minimumResults,
                preferredResults: preferredResults,
                maxProviderAttempts: maxProviderAttempts,
                onProgress: onProgress
            )
        } catch {
            // Provider exhaustion is not a screen-level failure. The caller keeps
            // any verified candidates already emitted by onProgress and may start
            // another pass. Fatal Package Engine errors are handled separately.
            return nil
        }
    }

    private func quoteOutboundSafely(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: [LiveFlightCandidate],
        inbound: [LiveFlightCandidate],
        hotelPrices: HotelPriceSearchSnapshot?,
        previous: [FlightOffer]
    ) async -> [FlightOffer] {
        guard !outbound.isEmpty, !inbound.isEmpty else { return previous }
        do {
            let response = try await packageEngine.quoteOutboundOptions(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                outbound: outbound,
                inbound: inbound,
                hotelPrices: hotelPrices
            )
            let newOffers = try bridge(candidates: outbound, quotes: response.options, direction: .outbound)
            return mergeOffers(previous, newOffers, anchor: trip.departureDate, flexibility: trip.flexibility)
        } catch {
            return previous
        }
    }

    private func quoteReturnSafely(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        selectedOutbound: LiveFlightCandidate,
        inbound: [LiveFlightCandidate],
        hotelPrices: HotelPriceSearchSnapshot?,
        previous: [FlightOffer]
    ) async -> [FlightOffer] {
        guard !inbound.isEmpty else { return previous }
        do {
            let response = try await packageEngine.quoteReturnOptions(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                selectedOutbound: selectedOutbound,
                inbound: inbound,
                hotelPrices: hotelPrices
            )
            let newOffers = try bridge(candidates: inbound, quotes: response.options, direction: .inbound)
            return mergeOffers(previous, newOffers, anchor: trip.returnDate, flexibility: trip.flexibility)
        } catch {
            return previous
        }
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

    private func prepareCaches(for trip: TripDraft) {
        let signature = makeSignature(trip)
        guard activeSignature != signature else { return }
        activeSignature = signature
        outboundCandidatesByID.removeAll()
        inboundCandidatesByID.removeAll()
        cachedHotelPrices = nil
    }

    private func cacheOutbound(_ values: [LiveFlightCandidate]) {
        for candidate in values where candidate.isDisplayableCandidate {
            outboundCandidatesByID[candidate.id] = candidate
        }
    }

    private func cacheInbound(_ values: [LiveFlightCandidate]) {
        for candidate in values where candidate.isDisplayableCandidate {
            inboundCandidatesByID[candidate.id] = candidate
        }
    }

    private func mergeCandidates(_ lhs: [LiveFlightCandidate], _ rhs: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var values = lhs
        var keys = Set(lhs.map(\.deduplicationKey))
        for candidate in rhs where candidate.isDisplayableCandidate {
            if keys.insert(candidate.deduplicationKey).inserted { values.append(candidate) }
        }
        return values
    }

    private func mergeOffers(
        _ lhs: [FlightOffer],
        _ rhs: [FlightOffer],
        anchor: Date,
        flexibility: DateFlexibility
    ) -> [FlightOffer] {
        var byCandidate: [String: FlightOffer] = [:]
        for offer in lhs + rhs where offer.isVerifiedForBooking {
            let key = offer.sourceCandidateID ?? offer.id
            if let current = byCandidate[key] {
                // A later live-hotel-price quote supersedes the earlier provisional
                // package quote for the same exact flight candidate.
                if offer.quoteId != current.quoteId { byCandidate[key] = offer }
            } else {
                byCandidate[key] = offer
            }
        }
        return rankedOffers(Array(byCandidate.values), anchor: anchor, flexibility: flexibility)
    }

    private func bridge(
        candidates: [LiveFlightCandidate],
        quotes: [PublicFlightOptionQuote],
        direction: FlightDirection
    ) throws -> [FlightOffer] {
        let visibleCandidates = candidates.filter(\.isDisplayableCandidate)
        var candidateMap: [String: LiveFlightCandidate] = [:]
        for candidate in visibleCandidates { candidateMap[candidate.id] = candidate }
        return quotes.compactMap { quote -> FlightOffer? in
            guard let candidate = candidateMap[quote.candidateId], candidate.isDisplayableCandidate else { return nil }
            let offer = FlightOffer(
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
                segments: candidate.segments,
                connectionAirports: candidate.connectionAirports
            )
            return offer.isVerifiedForBooking ? offer : nil
        }
    }

    private func rankedOffers(_ offers: [FlightOffer], anchor: Date, flexibility: DateFlexibility) -> [FlightOffer] {
        Array(offers.filter(\.isVerifiedForBooking).sorted { lhs, rhs in
            let calendar = Calendar.current
            let leftDay = abs(calendar.startOfDay(for: lhs.departureAt).timeIntervalSince(calendar.startOfDay(for: anchor)))
            let rightDay = abs(calendar.startOfDay(for: rhs.departureAt).timeIntervalSince(calendar.startOfDay(for: anchor)))
            if leftDay == 0 && rightDay != 0 { return true }
            if rightDay == 0 && leftDay != 0 { return false }
            if flexibility.isFlexibleDayRange {
                if leftDay != rightDay { return leftDay < rightDay }
                if lhs.totalPackagePrice != rhs.totalPackagePrice { return lhs.totalPackagePrice < rhs.totalPackagePrice }
            } else {
                if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
                if lhs.totalPackagePrice != rhs.totalPackagePrice { return lhs.totalPackagePrice < rhs.totalPackagePrice }
            }
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            return lhs.departureAt < rhs.departureAt
        }.prefix(18))
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

    func searchOutboundProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        switch AppConfig.flightEngineMode {
        case .sandbox:
            return try await sandbox.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate)
        case .officialWebBots:
            return try await real.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate)
        case .automatic:
            guard await canUseRemoteEngine() else {
                return try await sandbox.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate)
            }
            return try await real.searchOutboundProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, onUpdate: onUpdate)
        }
    }

    func searchReturnProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: FlightOffer,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        switch AppConfig.flightEngineMode {
        case .sandbox:
            return try await sandbox.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate)
        case .officialWebBots:
            guard outbound.sourceCandidateID != nil else { throw FlightEngineAvailabilityError.realOutboundRequired }
            return try await real.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate)
        case .automatic:
            if outbound.sourceCandidateID != nil {
                return try await real.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate)
            }
            return try await sandbox.searchReturnProgressive(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound, onUpdate: onUpdate)
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
