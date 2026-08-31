import Foundation

enum FlightCandidateRequirement: String, Codable, Hashable {
    /// Production flight discovery has one contract only: exact carrier flight
    /// number, complete route/segments, source-local times and a real fare.
    case displayable
}

struct FlightBotSearchRequest: Hashable, Codable {
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

struct LiveFlightCandidate: Identifiable, Hashable, Codable {
    let id: String
    let providerID: FlightBotProviderID
    let providerName: String
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
    let sourceURL: String
    let rawTextFingerprint: String
    let airlineCode: String?
    let segments: [FlightSegment]?
    let connectionAirports: [FlightAirportSnapshot]?

    init(
        id: String,
        providerID: FlightBotProviderID,
        providerName: String,
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
        sourceURL: String,
        rawTextFingerprint: String,
        airlineCode: String? = nil,
        segments: [FlightSegment]? = nil,
        connectionAirports: [FlightAirportSnapshot]? = nil
    ) {
        self.id = id
        self.providerID = providerID
        self.providerName = providerName
        self.direction = direction
        self.airline = airline
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
        self.observedCurrency = observedCurrency
        self.fareScope = fareScope
        self.observedAt = observedAt
        self.sourceURL = sourceURL
        self.rawTextFingerprint = rawTextFingerprint
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

    /// Hard boundary between internal fare references and itineraries that may be
    /// rendered or persisted as the user's selected flight.
    var isDisplayableCandidate: Bool {
        // Aggregators and internal reference rows are categorically forbidden at
        // the model boundary. A UI bug can therefore never turn Google Flights,
        // Skyscanner or REF-* metadata into a purchasable itinerary.
        guard !providerID.isAggregator,
              let provider = FlightBotProviderRegistry.providers.first(where: { $0.id == providerID }),
              let normalizedPrimary = FlightReferenceCatalog.normalizedVerifiedFlightNumber(flightNumber),
              provider.acceptsPrimaryFlightNumber(normalizedPrimary),
              let airlineCode = FlightReferenceCatalog.airlineCode(from: normalizedPrimary),
              let canonicalAirline = FlightReferenceCatalog.airline(code: airlineCode),
              airline.caseInsensitiveCompare(canonicalAirline.name) == .orderedSame,
              observedFare > 0,
              fareScope != .unknown,
              observedCurrency.range(of: "^[A-Za-z]{3}$", options: .regularExpression) != nil,
              let source = URL(string: sourceURL), provider.acceptsSourceURL(source),
              Date().timeIntervalSince(observedAt) >= -5 * 60,
              Date().timeIntervalSince(observedAt) <= 30 * 60,
              origin != destination,
              departureAt < arrivalAt,
              let segments,
              segments.count == stops + 1,
              !segments.isEmpty else { return false }

        guard FlightReferenceCatalog.normalizedVerifiedFlightNumber(segments[0].flightNumber) == normalizedPrimary,
              segments.first?.origin.code == origin,
              segments.last?.destination.code == destination else { return false }

        for (index, segment) in segments.enumerated() {
            guard let normalized = FlightReferenceCatalog.normalizedVerifiedFlightNumber(segment.flightNumber),
                  provider.acceptsPrimaryFlightNumber(normalized),
                  let code = FlightReferenceCatalog.airlineCode(from: normalized),
                  let reference = FlightReferenceCatalog.airline(code: code),
                  segment.airline.caseInsensitiveCompare(reference.name) == .orderedSame,
                  segment.origin.code != segment.destination.code,
                  segment.departureAt < segment.arrivalAt else { return false }
            if index > 0, segments[index - 1].destination.code != segment.origin.code { return false }
        }

        if stops == 0 { return connectionAirports == nil || connectionAirports?.isEmpty == true }
        guard let connectionAirports, connectionAirports.count == stops else { return false }
        let expectedConnections = segments.dropLast().map(\.destination.code)
        return connectionAirports.map(\.code) == expectedConnections
    }
}

struct FlightBotSearchSummary: Hashable, Codable {
    let searchID: String
    let requestedAt: Date
    let providersStarted: Int
    let providersSucceeded: Int
    let providersBlocked: Int
    let rawCandidateCount: Int
    let deduplicatedCandidateCount: Int
    let minimumTarget: Int
    let preferredTarget: Int
}
