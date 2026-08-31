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
        self.quoteService = BetaPackageQuoteService()
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

    func chooseHotel(_ hotel: HotelSummary) {
        if selectedHotel?.id != hotel.id {
            selectedRoom = nil
            selectedRoomCategory = nil
        }
        selectedHotel = hotel
        invalidateFlightAndQuoteSelection()
    }

    func chooseRoom(_ room: HotelRoom?) {
        selectedRoom = room
        if room != nil { selectedRoomCategory = nil }
        quote = nil
    }

    func chooseRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedRoomCategory = category
        if category != nil { selectedRoom = nil }
        quote = nil
    }

    /// Flight search may return ±1/±2 day options. Once the pilgrim selects one,
    /// that flight's local departure day becomes the authoritative trip date.
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
        }
    }

    func chooseMadinahHotel(_ hotel: HotelSummary) {
        if selectedMadinahHotel?.id != hotel.id {
            selectedMadinahRoom = nil
            selectedMadinahRoomCategory = nil
        }
        selectedMadinahHotel = hotel
        invalidateFlightAndQuoteSelection()
    }

    func chooseMadinahRoom(_ room: HotelRoom?) {
        selectedMadinahRoom = room
        if room != nil { selectedMadinahRoomCategory = nil }
        quote = nil
    }

    func chooseMadinahRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedMadinahRoomCategory = category
        if category != nil { selectedMadinahRoom = nil }
        quote = nil
    }

    private func invalidateFlightAndQuoteSelection() {
        selectedOutbound = nil
        selectedInbound = nil
        quote = nil
        hotelPriceSnapshot = nil
        pricingMakkahRoomID = nil
        pricingMadinahRoomID = nil
        (flightService as? AutomaticFlightSearchService)?.invalidateSession()
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
                    madinahHotel: selectedMadinahHotel
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
        let stay = TripStayPlanner.breakdown(for: trip)
        let nights = city == "Makkah" ? stay.makkahNights : stay.madinahNights

        // A concrete room must never inherit a generic cheapest-room web fare.
        // Use only its configured component rate unless a future provider returns
        // explicit room identity in HotelPriceObservation.
        if roomID == nil {
            let live = observations
                .filter { $0.hotelId == hotel.id && $0.amount > 0 }
                .sorted { $0.amount < $1.amount }
            for observation in live {
                do {
                    let usd = try await LocalFXRateService.shared.usd(observation.amount, currency: observation.currency)
                    guard let unit = LocalHotelPriceComponent.Unit(rawValue: observation.unit.rawValue) else { continue }
                    return LocalHotelPriceComponent(
                        amountUsd: usd,
                        unit: unit,
                        nights: max(1, nights),
                        hotelId: hotel.id,
                        roomId: nil,
                        source: observation.providerName
                    )
                } catch { continue }
            }
        }

        do {
            let configured = try await packageEngine.configuredHotelComponentPrice(hotelID: hotel.id, roomID: roomID)
            guard configured.amount > 0, let unit = LocalHotelPriceComponent.Unit(rawValue: configured.unit) else {
                throw LocalPricingError.missingHotelPrice(city)
            }
            return LocalHotelPriceComponent(
                amountUsd: configured.amount,
                unit: unit,
                nights: max(1, nights),
                hotelId: hotel.id,
                roomId: configured.roomId,
                source: configured.source
            )
        } catch {
            throw LocalPricingError.missingHotelPrice(city)
        }
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
