import Foundation
import Combine

@MainActor
final class JourneyStore: ObservableObject {
    @Published var trip = TripDraft()
    @Published var hotels: [HotelSummary] = []
    @Published var selectedHotel: HotelSummary?
    @Published var selectedOutbound: FlightOffer?
    @Published var selectedInbound: FlightOffer?
    @Published var quote: PackageQuote?

    @Published var isLoadingHotels = false
    @Published var isSearchingFlights = false
    @Published var errorMessage: String?

    let hotelService: HotelCatalogServicing
    let flightService: FlightSearchServicing
    let quoteService: PackageQuoteServicing

    init(
        hotelService: HotelCatalogServicing = HotelCatalogService(),
        flightService: FlightSearchServicing = AutomaticFlightSearchService(),
        quoteService: PackageQuoteServicing = BetaPackageQuoteService()
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
                selectedHotel = primaryHotelCandidate(from: all)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func primaryHotelCandidate(from all: [HotelSummary]) -> HotelSummary? {
        let exactStars = all.filter { $0.stars == trip.hotelStars }
        return exactStars.first ?? all.first
    }

    func resetAfterTripChange() {
        selectedHotel = nil
        selectedOutbound = nil
        selectedInbound = nil
        quote = nil
        hotels = []
    }

    func chooseHotel(_ hotel: HotelSummary) {
        selectedHotel = hotel
        selectedOutbound = nil
        selectedInbound = nil
        quote = nil
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
