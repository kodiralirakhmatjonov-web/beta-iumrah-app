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
        // Do not manufacture layover duration from timezone arithmetic. The
        // provider source remains authoritative; until it exposes an explicit
        // layover duration, present only the verified transfer airport/country.
        durationMinutes = 0
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
    let connectionAirports: [FlightAirportSnapshot]?

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
        segments: [FlightSegment]? = nil,
        connectionAirports: [FlightAirportSnapshot]? = nil
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
        self.connectionAirports = connectionAirports?.isEmpty == false ? connectionAirports : nil
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
        if let code = FlightReferenceCatalog.airlineCode(from: flightNumber) { return code }
        for segment in displaySegments {
            if let code = FlightReferenceCatalog.airlineCode(from: segment.flightNumber) { return code }
        }
        return nil
    }

    var flightNumbersSummary: String {
        var seen = Set<String>()
        return displaySegments
            .compactMap { FlightReferenceCatalog.normalizedVerifiedFlightNumber($0.flightNumber) }
            .filter { seen.insert($0).inserted }
            .joined(separator: " · ")
    }

    var airlinesSummary: String {
        var seen = Set<String>()
        let values = displaySegments.compactMap { segment -> String? in
            guard let code = FlightReferenceCatalog.airlineCode(from: segment.flightNumber),
                  let reference = FlightReferenceCatalog.airline(code: code) else { return nil }
            return reference.name
        }
        return values.filter { seen.insert($0).inserted }.joined(separator: " + ")
    }

    /// Final client-side safety gate. Only an itinerary made of exact carrier
    /// flight numbers and complete contiguous segments can be booked. Pricing
    /// references and aggregator placeholders are deliberately rejected here.
    var isVerifiedForBooking: Bool {
        guard let segments, !segments.isEmpty, segments.count == stops + 1 else { return false }
        guard segments.allSatisfy({ segment in
            FlightReferenceCatalog.normalizedVerifiedFlightNumber(segment.flightNumber) != nil &&
            FlightReferenceCatalog.airline(code: FlightReferenceCatalog.airlineCode(from: segment.flightNumber)) != nil &&
            segment.origin.code != segment.destination.code
        }) else { return false }
        guard segments.first?.origin.code == origin, segments.last?.destination.code == destination else { return false }
        guard zip(segments, segments.dropFirst()).allSatisfy({ $0.destination.code == $1.origin.code }) else { return false }
        return !flightNumbersSummary.isEmpty && !airlinesSummary.isEmpty
    }
}

struct PackageQuote: Hashable, Codable {
    let totalPackagePrice: Decimal
    let pricePerPerson: Decimal
    let currency: String
    let isEstimated: Bool
    let quoteId: String?
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
