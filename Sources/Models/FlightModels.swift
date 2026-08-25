import Foundation

enum FlightDirection: String, Codable, Hashable {
    case outbound
    case inbound
}

struct FlightAirportSnapshot: Hashable, Codable {
    let code: String
    let city: String?
    let name: String?
    let terminal: String?
    let timeZoneIdentifier: String?

    init(code: String, city: String? = nil, name: String? = nil, terminal: String? = nil, timeZoneIdentifier: String? = nil) {
        let upper = code.uppercased()
        let reference = FlightReferenceCatalog.airport(upper)
        self.code = upper
        self.city = city?.nilIfBlank ?? reference?.city
        self.name = name?.nilIfBlank ?? reference?.name
        self.terminal = terminal?.nilIfBlank
        self.timeZoneIdentifier = timeZoneIdentifier?.nilIfBlank ?? reference?.timeZoneIdentifier
    }

    var displayCity: String { city?.nilIfBlank ?? code }
    var displayAirport: String { name?.nilIfBlank ?? code }
}

struct FlightSegment: Identifiable, Hashable, Codable {
    let id: String
    let airline: String
    let airlineCode: String?
    let flightNumber: String
    let origin: FlightAirportSnapshot
    let destination: FlightAirportSnapshot
    let departureAt: Date
    let arrivalAt: Date
    let durationMinutes: Int
    let aircraft: String?
    let operatingCarrier: String?
    let cabin: String?

    init(
        id: String = UUID().uuidString,
        airline: String,
        airlineCode: String? = nil,
        flightNumber: String,
        origin: FlightAirportSnapshot,
        destination: FlightAirportSnapshot,
        departureAt: Date,
        arrivalAt: Date,
        durationMinutes: Int,
        aircraft: String? = nil,
        operatingCarrier: String? = nil,
        cabin: String? = nil
    ) {
        self.id = id
        self.airline = airline
        self.airlineCode = airlineCode?.uppercased()
        self.flightNumber = flightNumber
        self.origin = origin
        self.destination = destination
        self.departureAt = departureAt
        self.arrivalAt = arrivalAt
        self.durationMinutes = durationMinutes
        self.aircraft = aircraft?.nilIfBlank
        self.operatingCarrier = operatingCarrier?.nilIfBlank
        self.cabin = cabin?.nilIfBlank
    }
}

struct FlightLayover: Identifiable, Hashable {
    let id: String
    let airport: FlightAirportSnapshot
    let durationMinutes: Int
    let airportChange: Bool
    let overnight: Bool

    init(previous: FlightSegment, next: FlightSegment) {
        id = "\(previous.id)-\(next.id)"
        airport = previous.destination
        durationMinutes = max(0, Int(next.departureAt.timeIntervalSince(previous.arrivalAt) / 60))
        airportChange = previous.destination.code != next.origin.code
        let calendar = Calendar(identifier: .gregorian)
        overnight = !calendar.isDate(previous.arrivalAt, inSameDayAs: next.departureAt)
    }
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

    /// Public presentation metadata. Raw ticket fare is intentionally not stored here.
    let packageTotalPrice: Decimal?
    let quoteId: String?
    let sourceCandidateID: String?
    let airlineCode: String?
    let segments: [FlightSegment]?

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
        sourceCandidateID: String? = nil,
        airlineCode: String? = nil,
        segments: [FlightSegment]? = nil
    ) {
        self.id = id
        self.direction = direction
        self.airline = airline
        self.flightNumber = flightNumber
        self.origin = origin.uppercased()
        self.destination = destination.uppercased()
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
        self.airlineCode = airlineCode?.uppercased() ?? FlightReferenceCatalog.airlineCode(from: flightNumber)
        self.segments = segments?.isEmpty == false ? segments : nil
    }

    var displaySegments: [FlightSegment] {
        if let segments, !segments.isEmpty { return segments }
        let code = airlineCode ?? FlightReferenceCatalog.airlineCode(from: flightNumber)
        return [
            FlightSegment(
                id: "aggregate-\(id)",
                airline: airline,
                airlineCode: code,
                flightNumber: flightNumber,
                origin: FlightAirportSnapshot(code: origin),
                destination: FlightAirportSnapshot(code: destination),
                departureAt: departureAt,
                arrivalAt: arrivalAt,
                durationMinutes: durationMinutes
            )
        ]
    }

    var layovers: [FlightLayover] {
        let values = displaySegments
        guard values.count > 1 else { return [] }
        return zip(values, values.dropFirst()).map { FlightLayover(previous: $0.0, next: $0.1) }
    }

    var primaryAirlineCode: String? {
        airlineCode ?? displaySegments.first?.airlineCode
    }

    var flightNumbersSummary: String {
        var seen = Set<String>()
        return displaySegments.map(\.flightNumber).filter { seen.insert($0).inserted }.joined(separator: " · ")
    }

    var airlinesSummary: String {
        var seen = Set<String>()
        return displaySegments.map { FlightReferenceCatalog.airlineName(code: $0.airlineCode, fallback: $0.airline) }
            .filter { seen.insert($0).inserted }
            .joined(separator: " + ")
    }
}

struct PackageQuote: Hashable, Codable {
    let totalPackagePrice: Decimal
    let pricePerPerson: Decimal
    let currency: String
    let isEstimated: Bool
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
