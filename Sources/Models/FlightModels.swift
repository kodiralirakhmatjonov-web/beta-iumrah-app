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
        let normalizedFlightNumber = FlightReferenceCatalog.normalizedVerifiedFlightNumber(flightNumber)
            ?? flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.airlineCode = airlineCode?.uppercased() ?? FlightReferenceCatalog.airlineCode(from: normalizedFlightNumber)
        self.flightNumber = normalizedFlightNumber
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

    /// Historical property name retained for source compatibility. In Generator V2
    /// this is the displayed airline fare for this flight option. The final Umrah
    /// package selling price is calculated separately by LocalPackagePricingEngine.
    let totalPackagePrice: Decimal
    let currency: String
    let sourceLabel: String

    /// Legacy remote-pricing metadata retained for decoding older stored sessions.
    /// Generator V2 does not use these fields to calculate the final package price.
    let packageTotalPrice: Decimal?
    let quoteId: String?
    let sourceCandidateID: String?
    let airlineCode: String?
    let segments: [FlightSegment]?
    let connectionAirports: [FlightAirportSnapshot]?

    /// Actual ticket fare observed by the active flight data provider. Generator
    /// keeps fare components separate from the package selling price.
    let fareAmount: Decimal?
    let fareScope: FlightFareScope?
    let fareObservedAt: Date?
    let fareSourceURL: String?

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
        connectionAirports: [FlightAirportSnapshot]? = nil,
        fareAmount: Decimal? = nil,
        fareScope: FlightFareScope? = nil,
        fareObservedAt: Date? = nil,
        fareSourceURL: String? = nil
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
        self.fareAmount = fareAmount
        self.fareScope = fareScope
        self.fareObservedAt = fareObservedAt
        self.fareSourceURL = fareSourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? fareSourceURL : nil
    }

    /// Stable itinerary identity shared with LiveFlightCandidate. Upstream APIs
    /// can assign different IDs to the same physical itinerary, so deduplication
    /// uses flight/route/time/segments rather than provider IDs.
    var deduplicationKey: String {
        let normalized = FlightReferenceCatalog.normalizedVerifiedFlightNumber(flightNumber) ?? flightNumber.uppercased()
        let epoch = Int(departureAt.timeIntervalSince1970 / 300)
        let segmentKey = (segments ?? []).map { segment in
            let number = FlightReferenceCatalog.normalizedVerifiedFlightNumber(segment.flightNumber) ?? segment.flightNumber.uppercased()
            return "\(number)-\(segment.origin.code)-\(segment.destination.code)"
        }.joined(separator: "+")
        let connectionKey = (connectionAirports ?? []).map(\.code).joined(separator: "+")
        return "\(normalized)|\(origin)|\(destination)|\(epoch)|\(segmentKey)|\(connectionKey)".lowercased()
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

    /// Final client-side safety gate. Provider-specific response validation is
    /// performed by the flight API adapter; this model verifies the normalized
    /// itinerary/fare contract without any airline-bot registry dependency.
    var isVerifiedForBooking: Bool {
        let source = sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerSource = source.lowercased()
        let age = fareObservedAt.map { Date().timeIntervalSince($0) }
        guard !source.isEmpty,
              !lowerSource.contains("google flights"),
              !lowerSource.contains("skyscanner"),
              !lowerSource.contains("ref-google"),
              !lowerSource.contains("ref-skyscanner"),
              let exactPrimary = FlightReferenceCatalog.normalizedVerifiedFlightNumber(flightNumber),
              let primaryCode = FlightReferenceCatalog.airlineCode(from: exactPrimary),
              !airline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let fareAmount, fareAmount > 0,
              let fareScope, fareScope != .unknown,
              let age, age >= -5 * 60, age <= 30 * 60,
              currency.uppercased().range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              origin.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              destination.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              origin != destination,
              departureAt < arrivalAt,
              durationMinutes > 0,
              stops >= 0,
              let segments, !segments.isEmpty, segments.count == stops + 1 else { return false }

        if let fareSourceURL {
            guard let url = URL(string: fareSourceURL), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return false }
        }

        guard FlightReferenceCatalog.normalizedVerifiedFlightNumber(segments[0].flightNumber) == exactPrimary,
              segments.first?.origin.code == origin,
              segments.last?.destination.code == destination else { return false }

        for (index, segment) in segments.enumerated() {
            guard let normalized = FlightReferenceCatalog.normalizedVerifiedFlightNumber(segment.flightNumber),
                  let code = FlightReferenceCatalog.airlineCode(from: normalized),
                  segment.origin.code != segment.destination.code,
                  segment.departureAt < segment.arrivalAt else { return false }
            if index == 0, code != primaryCode { return false }
            if index > 0, segments[index - 1].destination.code != segment.origin.code { return false }
        }

        if stops == 0 { return connectionAirports == nil || connectionAirports?.isEmpty == true }
        guard let connectionAirports, connectionAirports.count == stops else { return false }
        return connectionAirports.map(\.code) == segments.dropLast().map(\.destination.code)
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
