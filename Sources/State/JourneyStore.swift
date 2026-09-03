import Foundation
import Combine

@MainActor
final class JourneyStore: ObservableObject {
    @Published var trip = TripDraft()

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
            hotels = all
            if selectedHotel == nil {
                selectedHotel = await resolvedPrimaryHotel(from: all, city: "Makkah") ?? primaryHotelCandidate(from: all)
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

        var lastError: Error?
        for city in ["Madinah", "Medina", "Al Madinah"] {
            do {
                let all = try await hotelService.listHotels(city: city)
                if !all.isEmpty {
                    madinahHotels = all
                    if selectedMadinahHotel == nil {
                        let aliases = ["Madinah", city, "Medina", "Al Madinah"]
                        selectedMadinahHotel = await resolvedPrimaryHotel(from: all, cityAliases: aliases) ?? primaryHotelCandidate(from: all)
                    }
                    return
                }
            } catch {
                lastError = error
            }
        }

        madinahHotels = []
        if let lastError {
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
        let exactStars = all.filter { $0.stars == trip.hotelStars }
        return exactStars.first ?? all.first
    }

    func resetAfterTripChange() {
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
        (flightService as? AutomaticFlightSearchService)?.invalidateSession()
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
        // flight tap and forced the user to wait for the same Booking lookup again.
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


    private func invalidateHotelPriceAndQuote() {
        quote = nil
        hotelPriceSnapshot = nil
        cancelHotelPricePrefetch()
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil
        (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
    }

    /// Starts current-price discovery as soon as the selected hotel/room and travel
    /// dates are known. The task is intentionally independent from a particular
    /// SwiftUI screen, so moving from hotel selection to flights does not cancel the
    /// lookup. HotelLivePriceSearchService coalesces this with the final quote call.
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
            // Coalesce the hotel + room callbacks emitted by HotelDetailView before
            // opening provider pages. A forced retry bypasses this tiny debounce.
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

    /// Starts return-ticket discovery while the pilgrim is still choosing the outbound
    /// flight. Selection remains independent: this only supplies a baseline return fare
    /// for package previews and warms the same Ignav cache used by ReturnFlightView.
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

    /// Uses exactly the same production pricing engine as FinalPackageView, but without
    /// mutating the selected quote. This is what flight cards show as "package / person".
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
            for offer in offers {
                let outbound = direction == .outbound ? offer : oppositeLeg
                let inbound = trip.isRoundTripFlight ? (direction == .inbound ? offer : oppositeLeg) : nil
                guard let outbound, outbound.isVerifiedForBooking,
                      let outboundFare = outbound.fareAmount, let outboundScope = outbound.fareScope else { continue }
                if trip.isRoundTripFlight {
                    guard let inbound, inbound.isVerifiedForBooking, inbound.fareAmount != nil, inbound.fareScope != nil else { continue }
                }
                let outboundUsd = try await LocalFXRateService.shared.usd(outboundFare, currency: outbound.currency)
                let inboundUsd: Decimal?
                if let inbound, let fare = inbound.fareAmount {
                    inboundUsd = try await LocalFXRateService.shared.usd(fare, currency: inbound.currency)
                } else {
                    inboundUsd = nil
                }
                let preview = try LocalPackagePricingEngine.calculate(
                    trip: trip,
                    outboundFareUsd: outboundUsd,
                    outboundScope: outboundScope,
                    outboundOffer: outbound,
                    inboundFareUsd: inboundUsd,
                    inboundScope: inbound?.fareScope,
                    inboundOffer: inbound,
                    makkahHotel: makkah,
                    madinahHotel: madinah
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
              outbound.isVerifiedForBooking,
              let outboundFare = outbound.fareAmount,
              let outboundScope = outbound.fareScope else {
            errorMessage = LocalPricingError.invalidFlightFare.localizedDescription
            quote = nil
            return
        }

        let inbound: FlightOffer?
        if trip.isRoundTripFlight {
            guard let value = selectedInbound,
                  value.isVerifiedForBooking,
                  value.fareAmount != nil,
                  value.fareScope != nil else {
                errorMessage = LocalPricingError.invalidFlightFare.localizedDescription
                quote = nil
                return
            }
            inbound = value
        } else {
            inbound = nil
        }

        if trip.scope == .makkahAndMadinah, selectedMadinahHotel == nil {
            errorMessage = LocalPricingError.missingHotelPrice("Madinah").localizedDescription
            quote = nil
            return
        }

        do {
            // FinalPackageView no longer starts the expensive provider lookup from
            // scratch. Normal generation reuses the search that began beside Ignav.
            // The explicit retry button may force a fresh Booking/Expedia lookup.
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

            // Each selected leg is a real independent one-way Ignav fare. Convert and
            // price them independently; a round trip is their sum, never a hidden
            // complete-itinerary fare copied onto both screens.
            let outboundFareUsd = try await LocalFXRateService.shared.usd(outboundFare, currency: outbound.currency)
            let inboundFareUsd: Decimal?
            if let inbound, let fare = inbound.fareAmount {
                inboundFareUsd = try await LocalFXRateService.shared.usd(fare, currency: inbound.currency)
            } else {
                inboundFareUsd = nil
            }

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
                outboundFareUsd: outboundFareUsd,
                outboundScope: outboundScope,
                outboundOffer: outbound,
                inboundFareUsd: inboundFareUsd,
                inboundScope: inbound?.fareScope,
                inboundOffer: inbound,
                makkahHotel: makkah,
                madinahHotel: madinah
            )
            errorMessage = nil
        } catch {
            quote = nil
            errorMessage = error.localizedDescription
        }
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

        // Hotel bots price the requested hotel stay. Internal Double/Triple/Quadruple
        // categories do not change provider pricing; only the trip room count does.
        _ = roomCapacity
        let effectiveRooms = max(1, trip.rooms)
        var verified: [(component: LocalHotelPriceComponent, totalUsd: Decimal)] = []

        for observation in observations where observation.isUsable(
            for: hotel,
            city: city,
            window: window,
            roomId: roomID
        ) {
            do {
                let usd = try await LocalFXRateService.shared.usd(observation.amount, currency: observation.currency)
                guard usd > 0, let unit = LocalHotelPriceComponent.Unit(rawValue: observation.unit.rawValue) else { continue }
                let component = LocalHotelPriceComponent(
                    amountUsd: usd,
                    unit: unit,
                    nights: max(1, window.nights),
                    rooms: effectiveRooms,
                    hotelId: hotel.id,
                    roomId: roomID,
                    source: observation.providerName
                )
                let totalUsd: Decimal
                switch unit {
                case .totalStay: totalUsd = usd
                case .perRoomStay: totalUsd = usd * Decimal(effectiveRooms)
                case .perRoomNight: totalUsd = usd * Decimal(effectiveRooms) * Decimal(max(1, window.nights))
                }
                let roomNights = Decimal(max(1, effectiveRooms * max(1, window.nights)))
                let normalizedRoomNightUsd = totalUsd / roomNights
                // Reject obvious parser artefacts (fees, loyalty credits, tiny
                // fragments or malformed totals) before they can under-price a
                // package. The range is deliberately broad; it is a corruption
                // guard, not a hotel-category price assumption.
                guard normalizedRoomNightUsd >= 15, normalizedRoomNightUsd <= 10_000 else { continue }
                verified.append((component, totalUsd))
            } catch {
                continue
            }
        }

        guard !verified.isEmpty else {
            // Never substitute package_primary_hotels or an estimated room rate for
            // a failed current-price check. Final package pricing is allowed only
            // after a current provider surface confirms this exact hotel/stay.
            throw LocalPricingError.missingHotelPrice(city)
        }

        // This is an indicative launch price followed by manual availability
        // confirmation. After parser-corruption guards have removed impossible
        // room-night values, use the lowest current provider rate instead of
        // automatically switching to the most expensive provider on disagreement.
        return verified.min(by: { $0.totalUsd < $1.totalUsd })!.component
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
