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

    // Production generator state. Discovery and pricing are owned by PackageEngine;
    // the iPhone only renders persisted server snapshots and submits candidate IDs.
    @Published var serverSearchSnapshot: ServerPackageSearchSnapshot?
    @Published var serverSearchId: String?
    @Published var serverSearchClientRequestId: String?
    @Published var selectedServerPackageKey: ServerPackageProductKey?
    @Published var serverMakkahRoomID: String?
    @Published var serverMadinahRoomID: String?
    @Published var serverIntercityTransport: ServerIntercityTransport?
    @Published var serverQuoteExpiresAt: String?
    @Published var isGeneratingPackages = false

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
        guard AppConfig.usesRemotePackagePricing else { return nil }
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

        serverSearchSnapshot = nil
        serverSearchId = nil
        serverSearchClientRequestId = nil
        selectedServerPackageKey = nil
        serverMakkahRoomID = nil
        serverMadinahRoomID = nil
        serverIntercityTransport = nil
        serverQuoteExpiresAt = nil
        isGeneratingPackages = false
    }

    func chooseHotel(_ hotel: HotelSummary) {
        if selectedHotel?.id != hotel.id {
            selectedRoom = nil
            selectedRoomCategory = nil
        }
        selectedHotel = hotel
        serverMakkahRoomID = nil
        if serverSearchId != nil {
            quote = nil
            serverQuoteExpiresAt = nil
        } else {
            invalidateFlightAndQuoteSelection()
        }
    }

    func chooseRoom(_ room: HotelRoom?) {
        selectedRoom = room
        if room != nil { selectedRoomCategory = nil }
        serverMakkahRoomID = room?.id
        quote = nil
        serverQuoteExpiresAt = nil
    }

    func chooseRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedRoomCategory = category
        if category != nil { selectedRoom = nil }
        serverMakkahRoomID = category?.id
        quote = nil
        serverQuoteExpiresAt = nil
    }

    func chooseMadinahHotel(_ hotel: HotelSummary) {
        if selectedMadinahHotel?.id != hotel.id {
            selectedMadinahRoom = nil
            selectedMadinahRoomCategory = nil
        }
        selectedMadinahHotel = hotel
        serverMadinahRoomID = nil
        if serverSearchId != nil {
            quote = nil
            serverQuoteExpiresAt = nil
        } else {
            invalidateFlightAndQuoteSelection()
        }
    }

    func chooseMadinahRoom(_ room: HotelRoom?) {
        selectedMadinahRoom = room
        if room != nil { selectedMadinahRoomCategory = nil }
        serverMadinahRoomID = room?.id
        quote = nil
        serverQuoteExpiresAt = nil
    }

    func chooseMadinahRoomCategory(_ category: IumrahRoomCategoryOption?) {
        selectedMadinahRoomCategory = category
        if category != nil { selectedMadinahRoom = nil }
        serverMadinahRoomID = category?.id
        quote = nil
        serverQuoteExpiresAt = nil
    }

    private func invalidateFlightAndQuoteSelection() {
        selectedOutbound = nil
        selectedInbound = nil
        quote = nil
    }

    func beginServerPackageSearch(force: Bool = false) async {
        guard trip.canContinue else { return }
        if !force, let serverSearchId, serverSearchSnapshot != nil {
            await refreshServerPackageSearch(searchId: serverSearchId)
            return
        }

        isGeneratingPackages = true
        errorMessage = nil
        if force {
            selectedOutbound = nil
            selectedInbound = nil
            selectedHotel = nil
            selectedMadinahHotel = nil
            quote = nil
            selectedServerPackageKey = nil
            serverMakkahRoomID = nil
            serverMadinahRoomID = nil
            serverIntercityTransport = nil
            serverQuoteExpiresAt = nil
        }
        let requestId = UUID().uuidString
        serverSearchClientRequestId = requestId
        do {
            let snapshot = try await packageEngine.createSearch(trip: trip, clientRequestId: requestId)
            serverSearchSnapshot = snapshot
            serverSearchId = snapshot.searchId
        } catch {
            errorMessage = error.localizedDescription
        }
        isGeneratingPackages = false
    }

    func refreshServerPackageSearch(searchId explicitSearchId: String? = nil) async {
        guard let searchId = explicitSearchId ?? serverSearchId else { return }
        do {
            let snapshot = try await packageEngine.searchSnapshot(searchId: searchId)
            guard serverSearchId == nil || serverSearchId == snapshot.searchId else { return }
            serverSearchId = snapshot.searchId
            serverSearchClientRequestId = snapshot.clientRequestId
            serverSearchSnapshot = snapshot
            errorMessage = snapshot.status == .failed ? serverSearchMessage(snapshot.message) : nil
        } catch {
            // A temporary network failure must not destroy the search: the Durable
            // Object continues processing and the next poll resumes from its snapshot.
            errorMessage = error.localizedDescription
        }
    }

    func applyGeneratedPackage(_ package: ServerGeneratedPackage, itinerary override: ServerPackageItinerary? = nil) throws {
        guard let snapshot = serverSearchSnapshot,
              package.status == .ready,
              let publicQuote = package.quote,
              let makkahHotel = package.hotelMakkah,
              let outboundID = package.selectedOutboundCandidateId,
              let inboundID = package.selectedInboundCandidateId,
              let outboundCandidate = snapshot.outboundFlights.first(where: { $0.id == outboundID }),
              let inboundCandidate = snapshot.inboundFlights.first(where: { $0.id == inboundID }) else {
            throw ServerPackageSelectionError.incompletePackage
        }
        guard outboundCandidate.dateOffset == inboundCandidate.dateOffset,
              outboundCandidate.dateOffset == package.selectedDateOffset else {
            throw ServerPackageSelectionError.flightDateMismatch
        }
        let itinerary = override ?? snapshot.itinerary.shifted(by: package.selectedDateOffset)
        guard let departureDate = ServerPackageDateParser.day(itinerary.startDate),
              let returnDate = ServerPackageDateParser.day(itinerary.endDate) else {
            throw ServerPackageSelectionError.invalidServerDates
        }
        guard let outbound = outboundCandidate.flightOffer(quote: publicQuote),
              let inbound = inboundCandidate.flightOffer(quote: publicQuote) else {
            throw ServerPackageSelectionError.unverifiedFlight
        }

        trip.departureDate = departureDate
        trip.returnDate = returnDate
        trip.scope = itinerary.includeMadinah ? .makkahAndMadinah : .makkahOnly
        trip.arrivalAirport = itinerary.outboundDestination == "MED" ? .madinah : .jeddah
        trip.packageTier = package.pricingTier
        trip.hotelStars = package.stars

        selectedHotel = makkahHotel.hotelSummary
        selectedRoom = nil
        selectedRoomCategory = nil
        serverMakkahRoomID = makkahHotel.roomId

        if itinerary.includeMadinah, let madinahHotel = package.hotelMadinah {
            selectedMadinahHotel = madinahHotel.hotelSummary
            serverMadinahRoomID = madinahHotel.roomId
        } else {
            selectedMadinahHotel = nil
            serverMadinahRoomID = nil
        }
        selectedMadinahRoom = nil
        selectedMadinahRoomCategory = nil

        selectedOutbound = outbound
        selectedInbound = inbound
        quote = publicQuote.packageQuote
        selectedServerPackageKey = package.key
        serverIntercityTransport = package.transport.type
        serverQuoteExpiresAt = package.quoteExpiresAt
        errorMessage = nil
    }

    func requoteServerSelection() async {
        guard let searchId = serverSearchId,
              let packageKey = selectedServerPackageKey,
              let outboundID = selectedOutbound?.sourceCandidateID,
              let inboundID = selectedInbound?.sourceCandidateID,
              let selectedHotel else { return }
        do {
            let response = try await packageEngine.requote(
                searchId: searchId,
                request: ServerPackageRequoteRequest(
                    packageKey: packageKey,
                    outboundCandidateId: outboundID,
                    inboundCandidateId: inboundID,
                    makkahHotelId: selectedHotel.id,
                    madinahHotelId: trip.scope == .makkahAndMadinah ? selectedMadinahHotel?.id : nil,
                    makkahRoomId: selectedRoom?.id ?? selectedRoomCategory?.id ?? serverMakkahRoomID,
                    madinahRoomId: trip.scope == .makkahAndMadinah ? (selectedMadinahRoom?.id ?? selectedMadinahRoomCategory?.id ?? serverMadinahRoomID) : nil
                )
            )
            try applyGeneratedPackage(response.package, itinerary: response.itinerary)
        } catch {
            quote = nil
            serverQuoteExpiresAt = nil
            errorMessage = error.localizedDescription
        }
    }

    var hasFreshAuthoritativeQuote: Bool {
        guard serverSearchId != nil,
              selectedServerPackageKey != nil,
              quote?.isEstimated == false,
              let quoteId = quote?.quoteId, !quoteId.isEmpty,
              let serverQuoteExpiresAt,
              let expiry = Self.isoDate(serverQuoteExpiresAt) else { return false }
        return expiry.timeIntervalSinceNow > 10
    }

    func buildQuote() async {
        if serverSearchId != nil, selectedServerPackageKey != nil {
            await requoteServerSelection()
            return
        }
        guard let hotel = selectedHotel,
              let outbound = selectedOutbound,
              let inbound = selectedInbound else { return }
        do {
            quote = try await quoteService.quote(trip: trip, hotel: hotel, outbound: outbound, inbound: inbound)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func isoDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return fractional.date(from: value) ?? standard.date(from: value)
    }

    private func serverSearchMessage(_ code: String?) -> String? {
        switch code {
        case "FLIGHT_PROVIDER_NOT_CONFIGURED": return "Flight provider is not configured on Package Engine."
        default: return code
        }
    }
}

enum ServerPackageSelectionError: LocalizedError {
    case incompletePackage
    case flightDateMismatch
    case invalidServerDates
    case unverifiedFlight

    var errorDescription: String? {
        switch self {
        case .incompletePackage: return "Server package is not ready yet."
        case .flightDateMismatch: return "Server flight dates do not match this package."
        case .invalidServerDates: return "Package Engine returned invalid travel dates."
        case .unverifiedFlight: return "Package Engine returned a flight that did not pass the booking safety gate."
        }
    }
}

