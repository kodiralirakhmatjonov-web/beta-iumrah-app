import Foundation
import MapKit

actor ZiyaratService {
    static let shared = ZiyaratService()

    func route(city: String = "Madinah") async -> ZiyaratRoute {
        do {
            let response: ZiyaratCatalogResponse = try await APIClient.shared.get(
                "/api/catalog/ziyarats",
                query: [URLQueryItem(name: "city", value: city)]
            )
            if let route = response.route, !route.places.isEmpty { return route }
        } catch {
            // The bundled Quba seed keeps the first Ziyarat useful before the cloud
            // migration is deployed; live Business data automatically replaces it.
        }
        return ZiyaratSeedData.medina
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
