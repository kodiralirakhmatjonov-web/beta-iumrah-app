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
    @Published private(set) var pricingMakkahRoomID: String?
    @Published private(set) var pricingMadinahRoomID: String?

    @Published var isLoadingHotels = false
    @Published var isLoadingMadinahHotels = false
    @Published var isSearchingFlights = false
    @Published var errorMessage: String?

    let hotelService: HotelCatalogServicing
    let flightService: FlightSearchServicing
    let quoteService: PackageQuoteServicing
    private let packageEngine = RemotePackageEngineClient()

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
        quote = nil
        hotelPriceSnapshot = nil
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil
        (flightService as? AutomaticFlightSearchService)?.invalidateSession()
    }

    func updateFlightFilters(_ filters: FlightSearchFilters) {
        guard trip.effectiveFlightFilters != filters else { return }
        trip.flightFilters = filters == .default ? nil : filters
        selectedOutbound = nil
        selectedInbound = nil
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
    }

    func chooseRoom(_ room: HotelRoom?) {
        selectedRoom = room
        if room != nil { selectedRoomCategory = nil }
        invalidateHotelPriceAndQuote()
    }

    func chooseRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedRoomCategory = category
        if category != nil { selectedRoom = nil }
        invalidateHotelPriceAndQuote()
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
        hotelPriceSnapshot = nil
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil

        let selectedDay = travelCalendarDay(for: offer.departureAt, airportCode: offer.origin)
        if !Calendar.current.isDate(selectedDay, inSameDayAs: trip.departureDate) {
            trip.departureDate = selectedDay
            (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
        }
    }

    func chooseInboundFlight(_ offer: FlightOffer) {
        selectedInbound = offer
        quote = nil
        hotelPriceSnapshot = nil
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil

        let selectedDay = travelCalendarDay(for: offer.departureAt, airportCode: offer.origin)
        if selectedDay > trip.departureDate, !Calendar.current.isDate(selectedDay, inSameDayAs: trip.returnDate) {
            trip.returnDate = selectedDay
            (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
        }
    }

    func chooseMadinahHotel(_ hotel: HotelSummary) {
        if selectedMadinahHotel?.id != hotel.id {
            selectedMadinahRoom = nil
            selectedMadinahRoomCategory = nil
        }
        selectedMadinahHotel = hotel
        invalidateHotelPriceAndQuote()
    }

    func chooseMadinahRoom(_ room: HotelRoom?) {
        selectedMadinahRoom = room
        if room != nil { selectedMadinahRoomCategory = nil }
        invalidateHotelPriceAndQuote()
    }

    func chooseMadinahRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedMadinahRoomCategory = category
        if category != nil { selectedMadinahRoom = nil }
        invalidateHotelPriceAndQuote()
    }


    private func invalidateHotelPriceAndQuote() {
        quote = nil
        hotelPriceSnapshot = nil
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil
        (flightService as? AutomaticFlightSearchService)?.invalidateHotelPrices()
    }

    var hasFinalGeneratorQuote: Bool {
        guard let quote, quote.isEstimated == false, let id = quote.quoteId else { return false }
        return id.hasPrefix("local-") && quote.totalPackagePrice > 0 && quote.pricePerPerson > 0
    }

    func buildQuote() async {
        guard let hotel = selectedHotel,
              let outbound = selectedOutbound,
              let inbound = selectedInbound,
              outbound.isVerifiedForBooking, inbound.isVerifiedForBooking,
              let outboundFare = outbound.fareAmount, let outboundScope = outbound.fareScope,
              let inboundFare = inbound.fareAmount, let inboundScope = inbound.fareScope else {
            errorMessage = LocalPricingError.invalidFlightFare.localizedDescription
            quote = nil
            return
        }
        if trip.scope == .makkahAndMadinah, selectedMadinahHotel == nil {
            errorMessage = LocalPricingError.missingHotelPrice("Madinah").localizedDescription
            quote = nil
            return
        }

        do {
            if let components = flightService as? GeneratorComponentProviding {
                hotelPriceSnapshot = await components.ensureHotelPrices(
                    trip: trip,
                    makkahHotel: hotel,
                    madinahHotel: selectedMadinahHotel,
                    makkahRoomId: selectedRoom?.id ?? selectedRoomCategory?.id,
                    makkahRoomName: selectedRoom?.name ?? selectedRoomCategory?.displayName,
                    madinahRoomId: selectedMadinahRoom?.id ?? selectedMadinahRoomCategory?.id,
                    madinahRoomName: selectedMadinahRoom?.name ?? selectedMadinahRoomCategory?.displayName
                )
            }
            let outboundUsd = try await LocalFXRateService.shared.usd(outboundFare, currency: outbound.currency)
            let inboundUsd = try await LocalFXRateService.shared.usd(inboundFare, currency: inbound.currency)
            let makkah = try await resolveHotelComponent(
                hotel: hotel,
                city: "Makkah",
                roomID: selectedRoom?.id ?? selectedRoomCategory?.id,
                observations: hotelPriceSnapshot?.makkah ?? []
            )
            let madinah: LocalHotelPriceComponent?
            if trip.scope == .makkahAndMadinah, let hotel = selectedMadinahHotel {
                madinah = try await resolveHotelComponent(
                    hotel: hotel,
                    city: "Madinah",
                    roomID: selectedMadinahRoom?.id ?? selectedMadinahRoomCategory?.id,
                    observations: hotelPriceSnapshot?.madinah ?? []
                )
            } else {
                madinah = nil
            }
            pricingMakkahRoomID = makkah.roomId
            pricingMadinahRoomID = madinah?.roomId
            quote = try LocalPackagePricingEngine.calculate(
                trip: trip,
                outboundFareUsd: outboundUsd,
                inboundFareUsd: inboundUsd,
                outboundScope: outboundScope,
                inboundScope: inboundScope,
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

        let bedOccupants = max(1, trip.adults + trip.children)
        let minimumRooms = max(1, Int(ceil(Double(bedOccupants) / 4.0)))
        let effectiveRooms = max(trip.rooms, minimumRooms)
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
                if totalUsd > 0 { verified.append((component, totalUsd)) }
            } catch {
                continue
            }
        }

        guard let best = verified.min(by: { $0.totalUsd < $1.totalUsd }) else {
            // Never substitute package_primary_hotels or an estimated room rate for
            // a failed current-price check. Final package pricing is allowed only
            // after an official live hotel surface confirms this exact stay/room.
            throw LocalPricingError.missingHotelPrice(city)
        }
        return best.component
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
