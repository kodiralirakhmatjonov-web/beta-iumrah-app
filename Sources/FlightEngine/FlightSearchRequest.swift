import Foundation

enum FlightCandidateRequirement: String, Codable, Hashable {
    case displayable
}

/// Provider-neutral request used by the generator. The next flight integration
/// (Ignav) plugs into this model without any airline-specific WebKit/server bot code.
struct FlightSearchRequest: Hashable, Codable {
    let id: String
    let direction: FlightDirection
    let origin: String
    let destination: String
    let date: Date
    let adults: Int
    let children: Int
    let infants: Int
    let cabin: String

    init(
        id: String = UUID().uuidString,
        direction: FlightDirection,
        origin: String,
        destination: String,
        date: Date,
        adults: Int,
        children: Int,
        infants: Int,
        cabin: String = "economy"
    ) {
        self.id = id
        self.direction = direction
        self.origin = origin.uppercased()
        self.destination = destination.uppercased()
        self.date = date
        self.adults = adults
        self.children = children
        self.infants = infants
        self.cabin = cabin
    }
}

enum FlightFareScope: String, Codable, Hashable {
    case perPassenger
    case totalParty
    case unknown
}

/// Normalized flight result independent of the transport used to discover it.
/// `sourceID`/`sourceName` describe the upstream data source (for example Ignav),
/// while the actual airline remains represented by `airline`/`flightNumber`.
struct LiveFlightCandidate: Identifiable, Hashable, Codable {
    let id: String
    let sourceID: String
    let sourceName: String
    let direction: FlightDirection
    let airline: String
    let flightNumber: String
    let origin: String
    let destination: String
    let departureAt: Date
    let arrivalAt: Date
    let stops: Int
    let durationMinutes: Int
    let observedFare: Decimal
    let observedCurrency: String
    let fareScope: FlightFareScope
    let observedAt: Date
    let sourceURL: String?
    let rawFingerprint: String?
    let airlineCode: String?
    let segments: [FlightSegment]?
    let connectionAirports: [FlightAirportSnapshot]?

    init(
        id: String,
        sourceID: String,
        sourceName: String,
        direction: FlightDirection,
        airline: String,
        flightNumber: String,
        origin: String,
        destination: String,
        departureAt: Date,
        arrivalAt: Date,
        stops: Int,
        durationMinutes: Int,
        observedFare: Decimal,
        observedCurrency: String,
        fareScope: FlightFareScope,
        observedAt: Date,
        sourceURL: String? = nil,
        rawFingerprint: String? = nil,
        airlineCode: String? = nil,
        segments: [FlightSegment]? = nil,
        connectionAirports: [FlightAirportSnapshot]? = nil
    ) {
        self.id = id
        self.sourceID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.direction = direction
        self.airline = airline.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFlightNumber = FlightReferenceCatalog.normalizedVerifiedFlightNumber(flightNumber)
            ?? flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.flightNumber = normalizedFlightNumber
        self.origin = origin.uppercased()
        self.destination = destination.uppercased()
        self.departureAt = departureAt
        self.arrivalAt = arrivalAt
        self.stops = stops
        self.durationMinutes = durationMinutes
        self.observedFare = observedFare
        self.observedCurrency = observedCurrency.uppercased()
        self.fareScope = fareScope
        self.observedAt = observedAt
        self.sourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        self.rawFingerprint = rawFingerprint?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        self.airlineCode = airlineCode?.uppercased() ?? FlightReferenceCatalog.airlineCode(from: normalizedFlightNumber)
        self.segments = segments?.isEmpty == false ? segments : nil
        self.connectionAirports = connectionAirports?.isEmpty == false ? connectionAirports : nil
    }

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

    /// Final provider-neutral safety gate before a result can be rendered.
    /// Source-specific validation belongs in the API adapter; this layer checks
    /// itinerary/fare coherence without depending on old airline-bot registries.
    var isDisplayableCandidate: Bool {
        let age = Date().timeIntervalSince(observedAt)
        guard !sourceID.isEmpty,
              !sourceName.isEmpty,
              let normalizedPrimary = FlightReferenceCatalog.normalizedVerifiedFlightNumber(flightNumber),
              let primaryCode = FlightReferenceCatalog.airlineCode(from: normalizedPrimary),
              observedFare > 0,
              fareScope != .unknown,
              observedCurrency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              age >= -5 * 60,
              age <= 30 * 60,
              origin.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              destination.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              origin != destination,
              departureAt < arrivalAt,
              stops >= 0,
              durationMinutes > 0,
              let segments,
              !segments.isEmpty,
              segments.count == stops + 1 else { return false }

        if let sourceURL {
            guard let url = URL(string: sourceURL), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return false }
        }

        guard FlightReferenceCatalog.normalizedVerifiedFlightNumber(segments[0].flightNumber) == normalizedPrimary,
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

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
