import Foundation
import Combine

@MainActor
final class JourneyStore: ObservableObject {
    @Published var trip = TripDraft()
    @Published var hotels: [HotelSummary] = []
    @Published var selectedHotel: HotelSummary?
    @Published var selectedRoom: HotelRoom?
    @Published var selectedOutbound: FlightOffer?
    @Published var selectedInbound: FlightOffer?
    @Published var quote: PackageQuote?

    @Published var isLoadingHotels = false
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
                selectedHotel = await resolvedPrimaryHotel(from: all) ?? primaryHotelCandidate(from: all)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    private func resolvedPrimaryHotel(from all: [HotelSummary]) async -> HotelSummary? {
        guard AppConfig.usesRemotePackagePricing else { return nil }
        do {
            let resolved = try await packageEngine.primaryHotel(
                tier: trip.packageTier,
                stars: trip.hotelStars,
                city: "Makkah"
            )
            return all.first(where: { $0.id == resolved.hotelId })
        } catch {
            return nil
        }
    }

    func primaryHotelCandidate(from all: [HotelSummary]) -> HotelSummary? {
        let exactStars = all.filter { $0.stars == trip.hotelStars }
        return exactStars.first ?? all.first
    }

    func resetAfterTripChange() {
        selectedHotel = nil
        selectedRoom = nil
        selectedOutbound = nil
        selectedInbound = nil
        quote = nil
        hotels = []
    }

    func chooseHotel(_ hotel: HotelSummary) {
        if selectedHotel?.id != hotel.id { selectedRoom = nil }
        selectedHotel = hotel
        selectedOutbound = nil
        selectedInbound = nil
        quote = nil
    }

    func chooseRoom(_ room: HotelRoom?) {
        selectedRoom = room
    }

    func buildQuote() async {
        guard let hotel = selectedHotel,
              let outbound = selectedOutbound,
              let inbound = selectedInbound else { return }
        do {
            quote = try await quoteService.quote(trip: trip, hotel: hotel, outbound: outbound, inbound: inbound)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
