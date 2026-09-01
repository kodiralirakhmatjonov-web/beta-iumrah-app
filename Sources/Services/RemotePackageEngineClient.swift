import Foundation

/// The Package Engine is intentionally hotel/booking-support only.
/// Flight inventory will be connected through the separate unified
/// FlightInventoryProviding boundary in the next Ignav integration update.
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

    func hotelPricingSources(hotelID: String) async throws -> [HotelPricingSourceIdentity] {
        let response: HotelPricingSourcesResponse = try await api.get(
            "/api/package/hotel/\(hotelID)/pricing-sources", timeoutInterval: 10
        )
        return response.ok ? response.sources : []
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
}
