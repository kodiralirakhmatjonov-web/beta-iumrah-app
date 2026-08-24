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

    /// Historical name retained for UI compatibility: this value is the PUBLIC
    /// package price per person after applying the selected flight option.
    let totalPackagePrice: Decimal
    let currency: String
    let sourceLabel: String

    /// 0.6 metadata. Raw ticket fare is intentionally not stored here.
    let packageTotalPrice: Decimal?
    let quoteId: String?
    let sourceCandidateID: String?

    init(
        id: String,
        direction: FlightDirection,
        airline: String,
        flightNumber: String,
        origin: String,
        destination: String,
        departureAt: Date,
        arrivalAt: Date,
        stops: Int,
        durationMinutes: Int,
        totalPackagePrice: Decimal,
        currency: String,
        sourceLabel: String,
        packageTotalPrice: Decimal? = nil,
        quoteId: String? = nil,
        sourceCandidateID: String? = nil
    ) {
        self.id = id
        self.direction = direction
        self.airline = airline
        self.flightNumber = flightNumber
        self.origin = origin
        self.destination = destination
        self.departureAt = departureAt
        self.arrivalAt = arrivalAt
        self.stops = stops
        self.durationMinutes = durationMinutes
        self.totalPackagePrice = totalPackagePrice
        self.currency = currency
        self.sourceLabel = sourceLabel
        self.packageTotalPrice = packageTotalPrice
        self.quoteId = quoteId
        self.sourceCandidateID = sourceCandidateID
    }

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
