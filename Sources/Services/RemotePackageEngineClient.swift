import Foundation

struct RemotePackageEngineClient {
    private let api = APIClient.shared

    func health() async throws -> PackageEngineHealthResponse {
        try await api.get(AppConfig.packageHealthPath, timeoutInterval: 8)
    }

    func roomCategories(hotelID: String) async throws -> [IumrahRoomCategoryOption] {
        let response: HotelRoomCategoriesResponse = try await api.get(
            "/api/package/hotel/\(hotelID)/room-categories"
        )
        return response.categories.sorted { $0.position < $1.position }
    }

    func primaryHotel(tier: PackageTier, stars: Int, city: String) async throws -> PrimaryHotelResolutionResponse {
        try await api.get(
            "/api/package/primary-hotel",
            query: [
                URLQueryItem(name: "tier", value: tier.rawValue),
                URLQueryItem(name: "stars", value: String(stars)),
                URLQueryItem(name: "city", value: city)
            ]
        )
    }

    func quote(
        trip: TripDraft,
        makkahHotelID: String?,
        madinahHotelID: String?,
        outbound: NormalizedFlightLegCost,
        inbound: NormalizedFlightLegCost
    ) async throws -> PublicPackageQuoteResponse {
        let stay = TripStayPlanner.breakdown(for: trip)
        let request = ConsumerPackageQuoteRequest(
            tier: trip.packageTier.rawValue,
            hotelStars: trip.hotelStars,
            includeMadinah: trip.scope == .makkahAndMadinah,
            totalDays: stay.totalDays,
            nights: .init(makkah: stay.makkahNights, madinah: stay.madinahNights),
            travelers: .init(adults: trip.adults, children: trip.children, infants: trip.infants, rooms: trip.rooms),
            travelStartDate: Self.dayFormatter.string(from: trip.departureDate),
            flights: .init(outbound: outbound, inbound: inbound),
            primaryHotelIds: .init(makkah: makkahHotelID, madinah: madinahHotelID),
            hotelPriceObservations: nil
        )
        return try await api.post(AppConfig.packageQuotePath, body: request, timeoutInterval: 15)
    }

    func quoteOutboundOptions(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: [LiveFlightCandidate],
        inbound: [LiveFlightCandidate],
        hotelPrices: HotelPriceSearchSnapshot? = nil
    ) async throws -> PublicFlightOptionsQuoteResponse {
        let request = OutboundFlightOptionsQuoteRequest(
            context: .init(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, hotelPrices: hotelPrices),
            outboundCandidates: try outbound.map { try FlightFareObservationRequest(candidate: $0) },
            returnCandidates: try inbound.map { try FlightFareObservationRequest(candidate: $0) }
        )
        return try await api.post(AppConfig.packageFlightOptionsQuotePath, body: request, timeoutInterval: 15)
    }

    func quoteReturnOptions(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        selectedOutbound: LiveFlightCandidate,
        inbound: [LiveFlightCandidate],
        hotelPrices: HotelPriceSearchSnapshot? = nil
    ) async throws -> PublicFlightOptionsQuoteResponse {
        let request = ReturnFlightOptionsQuoteRequest(
            context: .init(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, hotelPrices: hotelPrices),
            selectedOutbound: try FlightFareObservationRequest(candidate: selectedOutbound),
            returnCandidates: try inbound.map { try FlightFareObservationRequest(candidate: $0) }
        )
        return try await api.post(AppConfig.packageFlightOptionsQuotePath, body: request, timeoutInterval: 15)
    }
    func createSearch(trip: TripDraft, clientRequestId: String) async throws -> ServerPackageSearchSnapshot {
        try await api.post(
            AppConfig.packageSearchSessionsPath,
            body: ServerPackageSearchRequest(trip: trip, clientRequestId: clientRequestId),
            timeoutInterval: 18
        )
    }

    func searchSnapshot(searchId: String) async throws -> ServerPackageSearchSnapshot {
        try await api.get(
            "\(AppConfig.packageSearchSessionsPath)/\(searchId)",
            timeoutInterval: 12
        )
    }

    func requote(searchId: String, request: ServerPackageRequoteRequest) async throws -> ServerPackageRequoteResponse {
        try await api.post(
            "\(AppConfig.packageSearchSessionsPath)/\(searchId)/quote",
            body: request,
            timeoutInterval: 18
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

}
