import Foundation
import MapKit

actor ZiyaratService {
    static let shared = ZiyaratService()

    private let cachePrefix = "iumrah.ziyarats.catalog.v1."

    func route(city: String = "Madinah") async -> ZiyaratRoute {
        do {
            let response: ZiyaratCatalogResponse = try await APIClient.shared.get(
                "/api/catalog/ziyarats",
                query: [URLQueryItem(name: "city", value: city)]
            )
            if let route = response.route, !route.places.isEmpty {
                cache(route, city: city)
                return route
            }
        } catch {
            // A short network interruption should not collapse a previously loaded
            // multi-stop journey back to the one-place bundled seed.
        }

        if let cached = cachedRoute(city: city), !cached.places.isEmpty { return cached }
        return ZiyaratSeedData.fallback(city: city)
    }

    private func cache(_ route: ZiyaratRoute, city: String) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        UserDefaults.standard.set(data, forKey: cachePrefix + city.lowercased())
    }

    private func cachedRoute(city: String) -> ZiyaratRoute? {
        guard let data = UserDefaults.standard.data(forKey: cachePrefix + city.lowercased()) else { return nil }
        return try? JSONDecoder().decode(ZiyaratRoute.self, from: data)
    }
}

actor ZiyaratRouteService {
    static let shared = ZiyaratRouteService()

    func roadPolylines(for places: [ZiyaratPlace]) async -> [MKPolyline] {
        let ordered = places.sorted { $0.routeOrder < $1.routeOrder }
        guard ordered.count > 1 else { return [] }
        var result: [MKPolyline] = []
        for pair in zip(ordered, ordered.dropFirst()) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: pair.0.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: pair.1.coordinate))
            request.transportType = .automobile
            request.requestsAlternateRoutes = false
            if let response = try? await MKDirections(request: request).calculate(), let route = response.routes.first {
                result.append(route.polyline)
            } else {
                var coordinates = [pair.0.coordinate, pair.1.coordinate]
                result.append(MKPolyline(coordinates: &coordinates, count: coordinates.count))
            }
        }
        return result
    }
}
