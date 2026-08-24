import Foundation

enum FlightDirection: String, Codable, Hashable {
    case outbound
    case inbound
}

struct FlightOffer: Identifiable, Hashable, Codable {
    let id: String
    let direction: FlightDirection
    let airline: String
    let flightNumber: String
    let origin: String
    let destination: String
    let departureAt: Date
    let arrivalAt: Date
    let stops: Int
    let durationMinutes: Int
    let totalPackagePrice: Decimal
    let currency: String
    let sourceLabel: String

    var stopLabel: String {
        stops == 0 ? "Прямой" : "Пересадок: \(stops)"
    }
}

struct PackageQuote: Hashable, Codable {
    let totalPackagePrice: Decimal
    let pricePerPerson: Decimal
    let currency: String
    let isEstimated: Bool
}
