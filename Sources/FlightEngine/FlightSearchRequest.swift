import Foundation

enum FlightCandidateRequirement: String, Codable, Hashable {
    /// Candidate is eligible to be shown to the pilgrim. Exact carrier flight
    /// number, complete route/segment data, source-local times and fare are
    /// mandatory. Fare-only or aggregator-only observations are never rendered.
    case displayable

    /// Candidate is used only as an internal reference fare while the opposite
    /// direction is being priced. It is never rendered in the UI.
    case pricingReference
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
        self.flightNumber = flightNumber
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
        self.airlineCode = airlineCode?.uppercased() ?? FlightReferenceCatalog.airlineCode(from: flightNumber)
        self.segments = segments?.isEmpty == false ? segments : nil
        self.connectionAirports = connectionAirports?.isEmpty == false ? connectionAirports : nil
    }

    var deduplicationKey: String {
        let epoch = Int(departureAt.timeIntervalSince1970 / 300)
        let segmentKey = (segments ?? []).map { "\($0.flightNumber)-\($0.origin.code)-\($0.destination.code)" }.joined(separator: "+")
        let connectionKey = (connectionAirports ?? []).map(\.code).joined(separator: "+")
        return "\(airline.lowercased())|\(flightNumber.lowercased())|\(origin)|\(destination)|\(epoch)|\(segmentKey)|\(connectionKey)"
    }

    /// Hard boundary between internal fare references and itineraries that may be
    /// rendered or persisted as the user's selected flight.
    var isDisplayableCandidate: Bool {
        guard FlightReferenceCatalog.isVerifiedFlightNumber(flightNumber),
              let airlineCode,
              FlightReferenceCatalog.airline(code: airlineCode) != nil,
              !airline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              origin != destination,
              let segments,
              segments.count == stops + 1,
              !segments.isEmpty else { return false }

        guard segments.first?.origin.code == origin,
              segments.last?.destination.code == destination else { return false }

        for (index, segment) in segments.enumerated() {
            guard FlightReferenceCatalog.isVerifiedFlightNumber(segment.flightNumber),
                  let code = segment.airlineCode,
                  FlightReferenceCatalog.airline(code: code) != nil else { return false }
            if index > 0, segments[index - 1].destination.code != segment.origin.code { return false }
        }

        if stops == 0 { return connectionAirports == nil || connectionAirports?.isEmpty == true }
        return connectionAirports?.count == stops
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
