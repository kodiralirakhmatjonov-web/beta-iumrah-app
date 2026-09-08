import Foundation
import Combine

@MainActor
final class JourneyStore: ObservableObject {
    @Published var trip = TripDraft()

    /// Controls the three package-generation paths without changing the persisted
    /// TripDraft contract. Weekend keeps its existing DateFlexibility behavior;
    /// published/direct and flexible-date paths are session architecture state.
    @Published var packageFlightPath: PackageFlightPath = .publishedDirect
    @Published var selectedPublishedCompleteID: String?
    @Published var selectedPublishedOutboundID: String?
    @Published var selectedPublishedReturnID: String?

    // Transfer is a first-class generator stage shared by both flight paths.
    // The base transfer price is package-wide; vehicle class controls the service
    // experience, while Haramain is the only optional priced hybrid-route add-on.
    @Published var selectedTransferVehicle: TransferVehicleKind?
    @Published var haramainTrainSelected = false
    @Published var transferSelectionConfirmed = false

    @Published var hotels: [HotelSummary] = []
    @Published var selectedHotel: HotelSummary?
    @Published var selectedRoom: HotelRoom?
    @Published var selectedRoomCategory: IumrahRoomCategoryOption?

    @Published var madinahHotels: [HotelSummary] = []
    @Published var selectedMadinahHotel: HotelSummary?
    @Published var selectedMadinahRoom: HotelRoom?
    @Published var selectedMadinahRoomCategory: IumrahRoomCategoryOption?

    @Published var selectedOutbound: FlightOffer?
    @Published var selectedInbound: FlightOffer?
    @Published var quote: PackageQuote?
    @Published private(set) var hotelPriceSnapshot: HotelPriceSearchSnapshot?
    @Published private(set) var isSearchingHotelPrices = false
    @Published private(set) var pricingMakkahRoomID: String?
    @Published private(set) var pricingMadinahRoomID: String?
    @Published private(set) var prefetchedInboundOffers: [FlightOffer] = []

    @Published var isLoadingHotels = false
    @Published var isLoadingMadinahHotels = false
    @Published var isSearchingFlights = false
    @Published var errorMessage: String?

    let hotelService: HotelCatalogServicing
    let flightService: FlightSearchServicing
    let quoteService: PackageQuoteServicing
    private let packageEngine = RemotePackageEngineClient()
    private var hotelPricePrefetchTask: Task<Void, Never>?
    private var hotelPricePrefetchGeneration = UUID()
    private var inboundFlightPrefetchTask: Task<Void, Never>?

    init() {
        self.hotelService = HotelCatalogService()
        self.flightService = AutomaticFlightSearchService()
        self.quoteService = LocalOnlyPackageQuoteService()
    }

    init(
        hotelService: HotelCatalogServicing,
        flightService: FlightSearchServicing,
        quoteService: PackageQuoteServicing
    ) {
        self.hotelService = hotelService
        self.flightService = flightService
        self.quoteService = quoteService
    }

    func loadMakkahHotels() async {
        isLoadingHotels = true
        errorMessage = nil
        defer { isLoadingHotels = false }

        do {
            let all = try await hotelService.listHotels(city: "Makkah")
            // Keep the complete published catalogue in memory. A summary-level
            // 48h price may be stale even though hotel detail can already expose
            // the refreshed price. Filtering here was the reason the selector
            // could incorrectly become completely empty.
            hotels = all
            if selectedHotel == nil {
                let primaryCandidates = all.filter { $0.stars == trip.packageTier.primaryHotelStars }
                selectedHotel = await resolvedPrimaryHotel(from: primaryCandidates, city: "Makkah")
                    ?? primaryHotelCandidate(from: all)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMadinahHotels() async {
        guard trip.scope == .makkahAndMadinah else {
            madinahHotels = []
            selectedMadinahHotel = nil
            selectedMadinahRoom = nil
            selectedMadinahRoomCategory = nil
            return
        }

        isLoadingMadinahHotels = true
        errorMessage = nil
        defer { isLoadingMadinahHotels = false }

        // The Business catalogue has historically used several spellings for
        // Madinah. Merge them instead of stopping after the first non-empty alias;
        // otherwise valid hotels stored under another spelling disappear.
        let aliases = ["Madinah", "Medina", "Al Madinah", "Madinah Al Munawwarah", "Al Madinah Al Munawwarah"]
        var merged: [String: HotelSummary] = [:]
        var lastError: Error?

        for city in aliases {
            do {
                let values = try await hotelService.listHotels(city: city)
                for hotel in values { merged[hotel.id] = hotel }
            } catch {
                lastError = error
            }
        }

        let all = Array(merged.values).sorted {
            if $0.stars != $1.stars { return ($0.stars ?? 0) > ($1.stars ?? 0) }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        madinahHotels = all

        if selectedMadinahHotel == nil, !all.isEmpty {
            let primaryCandidates = all.filter { $0.stars == trip.packageTier.primaryHotelStars }
            selectedMadinahHotel = await resolvedPrimaryHotel(from: primaryCandidates, cityAliases: aliases)
                ?? primaryHotelCandidate(from: all)
        }

        if all.isEmpty, let lastError {
            errorMessage = lastError.localizedDescription
        }
    }

    private func resolvedPrimaryHotel(from all: [HotelSummary], city: String) async -> HotelSummary? {
        guard AppConfig.usesServerPrimaryHotelResolver else { return nil }
        do {
            let resolved = try await packageEngine.primaryHotel(
                tier: trip.packageTier,
                stars: trip.hotelStars,
                city: city
            )
            return all.first(where: { $0.id == resolved.hotelId })
        } catch {
            return nil
        }
    }

    private func resolvedPrimaryHotel(from all: [HotelSummary], cityAliases: [String]) async -> HotelSummary? {
        var seen = Set<String>()
        for city in cityAliases where seen.insert(city.lowercased()).inserted {
            if let hotel = await resolvedPrimaryHotel(from: all, city: city) {
                return hotel
            }
        }
        return nil
    }

    func primaryHotelCandidate(from all: [HotelSummary]) -> HotelSummary? {
        let exactStars = all.filter { $0.stars == trip.packageTier.primaryHotelStars }
        // Prefer a summary that is already price-ready, but never hide the hotel
        // catalogue merely because its list-row cache is stale. Final package
        // pricing still validates a fresh detail price before arithmetic runs.
        return exactStars.first(where: \.hasFreshCatalogPrice) ?? exactStars.first
    }

    /// Package category is the only hotel-level control shown to the pilgrim.
    /// Keep `hotelStars` synchronized internally so all existing booking/pricing
    /// contracts continue to work unchanged.
    func selectPackageTier(_ tier: PackageTier) {
        let expectedStars = tier.primaryHotelStars
        guard trip.packageTier != tier || trip.hotelStars != expectedStars else { return }

        trip.packageTier = tier
        trip.hotelStars = expectedStars

        // A category change invalidates only hotel choices and the quote. Flight
        // selection, direct-flight IDs, dates, passengers and Weekend state stay intact.
        selectedHotel = nil
        selectedRoom = nil
        selectedRoomCategory = nil
        hotels = []

        selectedMadinahHotel = nil
        selectedMadinahRoom = nil
        selectedMadinahRoomCategory = nil
        madinahHotels = []

        quote = nil
        hotelPriceSnapshot = nil
        cancelHotelPricePrefetch()
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil
        (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
        resetTransferSelection()
    }

    func resetAfterTripChange(keepingPublishedFlightSelection: Bool = false) {
        if !keepingPublishedFlightSelection { clearPublishedFlightSelection() }

        selectedHotel = nil
        selectedRoom = nil
        selectedRoomCategory = nil
        hotels = []

        selectedMadinahHotel = nil
        selectedMadinahRoom = nil
        selectedMadinahRoomCategory = nil
        madinahHotels = []

        selectedOutbound = nil
        selectedInbound = nil
        prefetchedInboundOffers = []
        inboundFlightPrefetchTask?.cancel()
        inboundFlightPrefetchTask = nil
        trip.saudiArrivalDate = nil
        quote = nil
        hotelPriceSnapshot = nil
        cancelHotelPricePrefetch()
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil
        resetTransferSelection()
        (flightService as? AutomaticFlightSearchService)?.invalidateSession()
    }

    var hasCompletePublishedFlightSelection: Bool {
        selectedPublishedCompleteID != nil ||
        (selectedPublishedOutboundID != nil && selectedPublishedReturnID != nil)
    }

    var publishedFlightSelection: CuratedPublishedFlightSelection {
        CuratedPublishedFlightSelection(
            completeID: selectedPublishedCompleteID,
            outboundID: selectedPublishedOutboundID,
            returnID: selectedPublishedReturnID
        )
    }

    func clearPublishedFlightSelection() {
        selectedPublishedCompleteID = nil
        selectedPublishedOutboundID = nil
        selectedPublishedReturnID = nil
    }

    /// Converts the selected D1-published direct itinerary into verified FlightOffer
    /// values and runs the existing local package-pricing engine. No Ignav search is
    /// performed here; the only flight request is the D1 recommendation resolver.
    @discardableResult
    func preparePublishedDirectQuote() async -> Bool {
        guard packageFlightPath == .publishedDirect, hasCompletePublishedFlightSelection else {
            errorMessage = "Published direct flight selection is incomplete."
            quote = nil
            return false
        }

        do {
            let resolved = try await CuratedFlightRecommendationService.shared.resolvePublishedSelection(
                trip: trip,
                selection: publishedFlightSelection
            )
            chooseOutboundFlight(resolved.outbound)
            chooseInboundFlight(resolved.inbound)
            scheduleHotelPricePrefetch()
            await buildQuote()
            return hasFinalGeneratorQuote
        } catch {
            errorMessage = error.localizedDescription
            quote = nil
            return false
        }
    }

    func updateFlightFilters(_ filters: FlightSearchFilters) {
        guard trip.effectiveFlightFilters != filters else { return }
        trip.flightFilters = filters == .default ? nil : filters
        selectedOutbound = nil
        selectedInbound = nil
        prefetchedInboundOffers = []
        inboundFlightPrefetchTask?.cancel()
        inboundFlightPrefetchTask = nil
        trip.saudiArrivalDate = nil
        quote = nil
        transferSelectionConfirmed = false
        (flightService as? AutomaticFlightSearchService)?.invalidateFlightInventory()
    }

    func chooseHotel(_ hotel: HotelSummary) {
        if selectedHotel?.id != hotel.id {
            selectedRoom = nil
            selectedRoomCategory = nil
        }
        selectedHotel = hotel
        invalidateHotelPriceAndQuote()
        scheduleHotelPricePrefetch()
    }

    func chooseRoom(_ room: HotelRoom?) {
        selectedRoom = room
        if room != nil { selectedRoomCategory = nil }
        invalidateHotelPriceAndQuote()
        scheduleHotelPricePrefetch()
    }

    func chooseRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedRoomCategory = category
        if category != nil { selectedRoom = nil }
        invalidateHotelPriceAndQuote()
        scheduleHotelPricePrefetch()
    }

    /// Weekly flight discovery may return a flight on another day in the seven-day
    /// window. Once the pilgrim selects one, that flight's local departure day
    /// becomes the authoritative trip date.
    /// Hotel verification is then repeated against those actual dates before
    /// local package pricing runs.
    func chooseOutboundFlight(_ offer: FlightOffer) {
        selectedOutbound = offer
        selectedInbound = nil
        quote = nil
        transferSelectionConfirmed = false
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil

        let selectedDepartureDay = travelCalendarDay(for: offer.departureAt, airportCode: offer.origin)
        let selectedArrivalDay = travelCalendarDay(for: offer.arrivalAt, airportCode: offer.destination)
        let previousHotelStart = trip.hotelStayStartDate
        let departureChanged = !Calendar.current.isDate(selectedDepartureDay, inSameDayAs: trip.departureDate)
        let hotelStartChanged = !Calendar.current.isDate(previousHotelStart, inSameDayAs: selectedArrivalDay)

        if departureChanged { trip.departureDate = selectedDepartureDay }
        trip.saudiArrivalDate = selectedArrivalDay

        // Preserve an already completed background hotel lookup whenever the actual
        // stay dates did not change. The old flow discarded a valid snapshot on every
        // flight tap and forced the user to wait for the same catalog price lookup again.
        if departureChanged || hotelStartChanged {
            hotelPriceSnapshot = nil
            cancelHotelPricePrefetch()
            (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
            scheduleHotelPricePrefetch()
        } else if hotelPriceSnapshot == nil && !isSearchingHotelPrices {
            scheduleHotelPricePrefetch()
        }
    }

    func chooseInboundFlight(_ offer: FlightOffer) {
        selectedInbound = offer
        quote = nil
        transferSelectionConfirmed = false
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil

        let selectedDay = travelCalendarDay(for: offer.departureAt, airportCode: offer.origin)
        let returnChanged = selectedDay > trip.departureDate && !Calendar.current.isDate(selectedDay, inSameDayAs: trip.returnDate)
        if returnChanged {
            trip.returnDate = selectedDay
            hotelPriceSnapshot = nil
            cancelHotelPricePrefetch()
            (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
            scheduleHotelPricePrefetch()
        } else if hotelPriceSnapshot == nil && !isSearchingHotelPrices {
            scheduleHotelPricePrefetch()
        }
    }

    func chooseMadinahHotel(_ hotel: HotelSummary) {
        if selectedMadinahHotel?.id != hotel.id {
            selectedMadinahRoom = nil
            selectedMadinahRoomCategory = nil
        }
        selectedMadinahHotel = hotel
        invalidateHotelPriceAndQuote()
        scheduleHotelPricePrefetch()
    }

    func chooseMadinahRoom(_ room: HotelRoom?) {
        selectedMadinahRoom = room
        if room != nil { selectedMadinahRoomCategory = nil }
        invalidateHotelPriceAndQuote()
        scheduleHotelPricePrefetch()
    }

    func chooseMadinahRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedMadinahRoomCategory = category
        if category != nil { selectedMadinahRoom = nil }
        invalidateHotelPriceAndQuote()
        scheduleHotelPricePrefetch()
    }


    func recommendedTransferVehicle() -> TransferVehicleKind {
        if trip.packageTier == .luxury { return .yukon }
        return trip.travelerCount <= TransferVehicleKind.malibu.passengerCapacity ? .malibu : .carnival
    }

    func chooseTransferVehicle(_ vehicle: TransferVehicleKind) {
        guard selectedTransferVehicle != vehicle else { return }
        selectedTransferVehicle = vehicle
        transferSelectionConfirmed = false
        // Rebuild the final generator snapshot so iumrah Business receives the
        // exact selected vehicle class even though base transfer pricing is fixed.
        quote = nil
    }

    func setHaramainTrainSelected(_ selected: Bool) {
        let allowed = trip.scope == .makkahAndMadinah
        let resolved = allowed && selected
        guard haramainTrainSelected != resolved else { return }
        haramainTrainSelected = resolved
        transferSelectionConfirmed = false
        quote = nil
    }

    func confirmTransferSelection() {
        if selectedTransferVehicle == nil { selectedTransferVehicle = recommendedTransferVehicle() }
        transferSelectionConfirmed = true
    }

    func resetTransferSelection() {
        selectedTransferVehicle = nil
        haramainTrainSelected = false
        transferSelectionConfirmed = false
    }

    var haramainTrainAddOnUsd: Decimal {
        LocalPackagePricingEngine.haramainPublicAddOnEstimateUsd(
            travelers: trip.travelerCount,
            tier: trip.packageTier
        )
    }


    private func invalidateHotelPriceAndQuote() {
        quote = nil
        transferSelectionConfirmed = false
        hotelPriceSnapshot = nil
        cancelHotelPricePrefetch()
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil
        (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
    }

    /// Warms the server-maintained hotel catalog price as soon as the selected
    /// hotel/room and travel dates are known. This is a cheap D1-backed cache lookup;
    /// Beta never opens Booking/Expedia or runs hotel price bots on the pilgrim device.
    func scheduleHotelPricePrefetch(forceRefresh: Bool = false) {
        if !forceRefresh, hotelPricePrefetchTask != nil { return }
        if !forceRefresh, let snapshot = hotelPriceSnapshot, isCompleteHotelSnapshot(snapshot) { return }
        guard let components = flightService as? GeneratorComponentProviding,
              let makkahHotel = selectedHotel else { return }
        if trip.scope == .makkahAndMadinah, selectedMadinahHotel == nil { return }

        cancelHotelPricePrefetch()
        let generation = UUID()
        hotelPricePrefetchGeneration = generation
        isSearchingHotelPrices = true

        let tripSnapshot = trip
        let madinahHotel = selectedMadinahHotel
        let makkahRoomId = selectedRoom?.id ?? selectedRoomCategory?.id
        let makkahRoomName = selectedRoom?.name ?? selectedRoomCategory?.displayName
        let makkahRoomCapacity = selectedRoom?.maxGuests ?? selectedRoomCategory?.maxGuests
        let madinahRoomId = selectedMadinahRoom?.id ?? selectedMadinahRoomCategory?.id
        let madinahRoomName = selectedMadinahRoom?.name ?? selectedMadinahRoomCategory?.displayName
        let madinahRoomCapacity = selectedMadinahRoom?.maxGuests ?? selectedMadinahRoomCategory?.maxGuests

        hotelPricePrefetchTask = Task { @MainActor [weak self] in
            // Coalesce hotel + room callbacks before reading the same catalog cache.
            // A forced retry bypasses this tiny debounce and rechecks the public hotel detail.
            if !forceRefresh { try? await Task.sleep(for: .milliseconds(180)) }
            guard !Task.isCancelled else {
                if self?.hotelPricePrefetchGeneration == generation { self?.isSearchingHotelPrices = false }
                return
            }
            let snapshot = await components.ensureHotelPrices(
                trip: tripSnapshot,
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
            guard let self,
                  !Task.isCancelled,
                  self.hotelPricePrefetchGeneration == generation else { return }
            self.hotelPriceSnapshot = snapshot
            self.isSearchingHotelPrices = false
            self.hotelPricePrefetchTask = nil
        }
    }

    private func cancelHotelPricePrefetch() {
        hotelPricePrefetchGeneration = UUID()
        hotelPricePrefetchTask?.cancel()
        hotelPricePrefetchTask = nil
        isSearchingHotelPrices = false
    }

    private func isCompleteHotelSnapshot(_ snapshot: HotelPriceSearchSnapshot) -> Bool {
        !snapshot.makkah.isEmpty && (trip.scope != .makkahAndMadinah || !snapshot.madinah.isEmpty)
    }

    /// Projects compatible return legs from the complete Ignav itineraries already
    /// fetched for the outbound screen. In the normal path this does not buy/search a
    /// second one-way ticket and does not add another fare; it only warms return UI rows.
    func prefetchReturnFlightsIfNeeded(referenceOutbound: FlightOffer) {
        guard trip.isRoundTripFlight, prefetchedInboundOffers.isEmpty, inboundFlightPrefetchTask == nil,
              let makkahHotel = selectedHotel else { return }
        if trip.scope == .makkahAndMadinah, selectedMadinahHotel == nil { return }
        let tripSnapshot = trip
        let madinahHotel = selectedMadinahHotel
        inboundFlightPrefetchTask = Task { @MainActor [weak self] in
            defer { self?.inboundFlightPrefetchTask = nil }
            do {
                let values = try await self?.flightService.searchReturn(
                    trip: tripSnapshot,
                    makkahHotel: makkahHotel,
                    madinahHotel: madinahHotel,
                    outbound: referenceOutbound
                ) ?? []
                guard !Task.isCancelled else { return }
                self?.prefetchedInboundOffers = values.filter(\.isVerifiedForBooking)
            } catch {
                // Prefetch is opportunistic. ReturnFlightView still has its normal
                // explicit search/retry path and should not show a failure here.
            }
        }
    }

    func clearPrefetchedReturnFlights() {
        inboundFlightPrefetchTask?.cancel()
        inboundFlightPrefetchTask = nil
        prefetchedInboundOffers = []
    }

    func awaitPrefetchedReturnFlights() async -> [FlightOffer] {
        if let task = inboundFlightPrefetchTask { await task.value }
        return prefetchedInboundOffers
    }

    /// Uses the exact same Expedia-style pricing engine as FinalPackageView.
    /// Every visible round-trip row already carries one complete Ignav itinerary fare;
    /// previews never add two separately priced one-way tickets.
    func packagePricePreviews(
        offers: [FlightOffer],
        direction: FlightDirection,
        oppositeLeg: FlightOffer?
    ) async -> [String: Decimal] {
        guard !offers.isEmpty, let hotel = selectedHotel, let snapshot = hotelPriceSnapshot,
              isCompleteHotelSnapshot(snapshot) else { return [:] }
        if trip.scope == .makkahAndMadinah, selectedMadinahHotel == nil { return [:] }

        do {
            let makkah = try await resolveHotelComponent(
                hotel: hotel,
                city: "Makkah",
                roomID: selectedRoom?.id ?? selectedRoomCategory?.id,
                roomCapacity: selectedRoom?.maxGuests ?? selectedRoomCategory?.maxGuests,
                observations: snapshot.makkah
            )
            let madinah: LocalHotelPriceComponent?
            if trip.scope == .makkahAndMadinah, let selectedMadinahHotel {
                madinah = try await resolveHotelComponent(
                    hotel: selectedMadinahHotel,
                    city: "Madinah",
                    roomID: selectedMadinahRoom?.id ?? selectedMadinahRoomCategory?.id,
                    roomCapacity: selectedMadinahRoom?.maxGuests ?? selectedMadinahRoomCategory?.maxGuests,
                    observations: snapshot.madinah
                )
            } else {
                madinah = nil
            }

            var output: [String: Decimal] = [:]
            for offer in offers where offer.isVerifiedForBooking {
                guard let fare = offer.fareAmount, let scope = offer.fareScope else { continue }
                let outbound = direction == .outbound ? offer : oppositeLeg
                guard let outbound, outbound.isVerifiedForBooking else { continue }

                let journeyFareUsd = try await LocalFXRateService.shared.usd(fare, currency: offer.currency)
                let preview = try LocalPackagePricingEngine.calculate(
                    trip: trip,
                    journeyFareUsd: journeyFareUsd,
                    journeyFareScope: scope,
                    pricingOffer: offer,
                    outboundOffer: outbound,
                    inboundOffer: direction == .inbound ? offer : nil,
                    makkahHotel: makkah,
                    madinahHotel: madinah,
                    includeHaramainTrain: haramainTrainSelected,
                    transferVehicle: selectedTransferVehicle
                )
                output[offer.id] = preview.pricePerPerson
            }
            return output
        } catch {
            return [:]
        }
    }

    var hasFinalGeneratorQuote: Bool {
        guard let quote, let id = quote.quoteId else { return false }
        return id.hasPrefix("local-") && quote.totalPackagePrice > 0 && quote.pricePerPerson > 0
    }

    func buildQuote(forceHotelRefresh: Bool = false) async {
        guard let hotel = selectedHotel,
              let outbound = selectedOutbound,
              outbound.isVerifiedForBooking else {
            errorMessage = LocalPricingError.invalidFlightFare.localizedDescription
            quote = nil
            return
        }

        let inbound: FlightOffer?
        let pricingOffer: FlightOffer
        if trip.isRoundTripFlight {
            guard let value = selectedInbound,
                  value.isVerifiedForBooking,
                  returnOffer(value, matches: outbound),
                  value.fareAmount != nil,
                  value.fareScope != nil else {
                errorMessage = LocalPricingError.invalidFlightFare.localizedDescription
                quote = nil
                return
            }
            inbound = value
            // The return row represents the exact selected outbound+return Ignav
            // itinerary, so its fare is the authoritative complete-journey fare.
            pricingOffer = value
        } else {
            guard outbound.fareAmount != nil, outbound.fareScope != nil else {
                errorMessage = LocalPricingError.invalidFlightFare.localizedDescription
                quote = nil
                return
            }
            inbound = nil
            pricingOffer = outbound
        }

        if trip.scope == .makkahAndMadinah, selectedMadinahHotel == nil {
            errorMessage = LocalPricingError.missingHotelPrice("Madinah").localizedDescription
            quote = nil
            return
        }

        do {
            if let task = hotelPricePrefetchTask { await task.value }
            if forceHotelRefresh, let components = flightService as? GeneratorComponentProviding {
                hotelPriceSnapshot = await components.ensureHotelPrices(
                    trip: trip,
                    makkahHotel: hotel,
                    madinahHotel: selectedMadinahHotel,
                    makkahRoomId: selectedRoom?.id ?? selectedRoomCategory?.id,
                    makkahRoomName: selectedRoom?.name ?? selectedRoomCategory?.displayName,
                    makkahRoomCapacity: selectedRoom?.maxGuests ?? selectedRoomCategory?.maxGuests,
                    madinahRoomId: selectedMadinahRoom?.id ?? selectedMadinahRoomCategory?.id,
                    madinahRoomName: selectedMadinahRoom?.name ?? selectedMadinahRoomCategory?.displayName,
                    madinahRoomCapacity: selectedMadinahRoom?.maxGuests ?? selectedMadinahRoomCategory?.maxGuests,
                    forceRefresh: true
                )
            }
            guard let currentHotelSnapshot = hotelPriceSnapshot, isCompleteHotelSnapshot(currentHotelSnapshot) else {
                throw LocalPricingError.missingHotelPrice(
                    hotelPriceSnapshot?.makkah.isEmpty == false ? "Madinah" : "Makkah"
                )
            }

            guard let rawFare = pricingOffer.fareAmount, let fareScope = pricingOffer.fareScope else {
                throw LocalPricingError.invalidFlightFare
            }
            let journeyFareUsd = try await LocalFXRateService.shared.usd(rawFare, currency: pricingOffer.currency)

            let makkah = try await resolveHotelComponent(
                hotel: hotel,
                city: "Makkah",
                roomID: selectedRoom?.id ?? selectedRoomCategory?.id,
                roomCapacity: selectedRoom?.maxGuests ?? selectedRoomCategory?.maxGuests,
                observations: currentHotelSnapshot.makkah
            )
            let madinah: LocalHotelPriceComponent?
            if trip.scope == .makkahAndMadinah, let hotel = selectedMadinahHotel {
                madinah = try await resolveHotelComponent(
                    hotel: hotel,
                    city: "Madinah",
                    roomID: selectedMadinahRoom?.id ?? selectedMadinahRoomCategory?.id,
                    roomCapacity: selectedMadinahRoom?.maxGuests ?? selectedMadinahRoomCategory?.maxGuests,
                    observations: currentHotelSnapshot.madinah
                )
            } else {
                madinah = nil
            }
            pricingMakkahRoomID = makkah.roomId
            pricingMadinahRoomID = madinah?.roomId

            quote = try LocalPackagePricingEngine.calculate(
                trip: trip,
                journeyFareUsd: journeyFareUsd,
                journeyFareScope: fareScope,
                pricingOffer: pricingOffer,
                outboundOffer: outbound,
                inboundOffer: inbound,
                makkahHotel: makkah,
                madinahHotel: madinah,
                includeHaramainTrain: haramainTrainSelected,
                transferVehicle: selectedTransferVehicle
            )
            errorMessage = nil
        } catch {
            quote = nil
            errorMessage = error.localizedDescription
        }
    }

    private func returnOffer(_ inbound: FlightOffer, matches outbound: FlightOffer) -> Bool {
        guard let paired = inbound.pairedLeg else { return false }
        let selectedNumbers = Set(outbound.displaySegments.compactMap { FlightReferenceCatalog.normalizedVerifiedFlightNumber($0.flightNumber) })
        let pairedNumbers = Set((paired.segments ?? []).compactMap { FlightReferenceCatalog.normalizedVerifiedFlightNumber($0.flightNumber) })
        if !selectedNumbers.isEmpty && selectedNumbers != pairedNumbers { return false }
        return paired.origin.caseInsensitiveCompare(outbound.origin) == .orderedSame &&
            paired.destination.caseInsensitiveCompare(outbound.destination) == .orderedSame &&
            abs(paired.departureAt.timeIntervalSince(outbound.departureAt)) < 5 * 60
    }

    private func resolveHotelComponent(
        hotel: HotelSummary,
        city: String,
        roomID: String?,
        roomCapacity: Int?,
        observations: [HotelPriceObservation]
    ) async throws -> LocalHotelPriceComponent {
        let windows = TripStayPlanner.windows(for: trip, calendar: Calendar(identifier: .gregorian))
        let window: TripStayWindow
        if city == "Makkah" {
            window = windows.makkah
        } else if let madinah = windows.madinah {
            window = madinah
        } else {
            throw LocalPricingError.missingHotelPrice(city)
        }

        _ = roomCapacity
        let effectiveRooms = max(1, trip.rooms)

        // Production hotel pricing has exactly one unit. Any legacy total-stay or
        // per-room-stay observation is rejected instead of silently applying a
        // different multiplication rule.
        for observation in observations where observation.unit == .perRoomNight && observation.isUsable(
            for: hotel,
            city: city,
            window: window,
            roomId: roomID
        ) {
            do {
                let nightlyUsd = try await LocalFXRateService.shared.usd(observation.amount, currency: observation.currency)
                guard nightlyUsd >= 15, nightlyUsd <= 10_000 else { continue }
                return LocalHotelPriceComponent(
                    nightlyUsd: nightlyUsd,
                    nights: max(1, window.nights),
                    rooms: effectiveRooms,
                    hotelId: hotel.id,
                    roomId: roomID,
                    source: observation.providerName
                )
            } catch {
                continue
            }
        }

        throw LocalPricingError.missingHotelPrice(city)
    }

    private func travelCalendarDay(for date: Date, airportCode: String) -> Date {
        var source = Calendar(identifier: .gregorian)
        source.timeZone = FlightReferenceCatalog.timeZone(for: airportCode) ?? TimeZone(secondsFromGMT: 0)!
        let parts = source.dateComponents([.year, .month, .day], from: date)

        var local = Calendar.current
        local.timeZone = .current
        return local.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12))
            ?? local.startOfDay(for: date)
    }

}
