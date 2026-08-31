import Foundation

struct ServerFlightProviderSearchRequest: Encodable {
    struct Travelers: Encodable {
        let adults: Int
        let children: Int
        let infants: Int
        let rooms: Int
    }
    let providerId: String
    let direction: FlightDirection
    let origin: String
    let destination: String
    let travelDate: String
    let dateOffset: Int
    let travelers: Travelers
}

struct ServerFlightProviderSearchResponse: Decodable {
    let ok: Bool
    let providerId: String
    let fromCache: Bool
    let candidates: [ServerFlightComponentCandidate]
    let providerError: String?
    let searchedAt: String
}

struct ServerFlightComponentSegment: Decodable {
    let id: String
    let airline: String
    let airlineCode: String
    let flightNumber: String
    let origin: String
    let destination: String
    let departureAt: String
    let arrivalAt: String
    let durationMinutes: Int
    let originTerminal: String?
    let destinationTerminal: String?
    let aircraft: String?
    let operatingCarrier: String?
    let cabin: String?
}

struct ServerFlightComponentCandidate: Decodable {
    let id: String
    let providerId: String
    let sourceLabel: String
    let direction: String
    let dateOffset: Int
    let travelDate: String
    let origin: String
    let destination: String
    let airline: String
    let airlineCode: String
    let flightNumber: String
    let departureAt: String
    let arrivalAt: String
    let durationMinutes: Int
    let stops: Int
    let currency: String
    let segments: [ServerFlightComponentSegment]
    let fareAmountUsd: Decimal?
    let fareScope: String?
    let observedAt: String?
    let sourceURL: String?

    func liveCandidate() -> LiveFlightCandidate? {
        guard let provider = FlightBotProviderID(rawValue: providerId), !provider.isAggregator,
              let providerConfig = FlightBotProviderRegistry.providers.first(where: { $0.id == provider }),
              providerConfig.supportsServerSearch,
              providerConfig.acceptsPrimaryFlightNumber(flightNumber),
              let sourceURL, let trustedSource = URL(string: sourceURL), providerConfig.acceptsSourceURL(trustedSource),
              let departure = ServerPackageDateParser.dateTime(departureAt, airportCode: origin),
              let arrival = ServerPackageDateParser.dateTime(arrivalAt, airportCode: destination),
              Self.localDay(departure, airportCode: origin) == travelDate,
              currency.uppercased() == "USD",
              let fare = fareAmountUsd, fare > 0,
              let fareScope, ["totalParty", "perPassenger"].contains(fareScope),
              let observedAt, let observed = Self.isoDate(observedAt) else { return nil }
        let normalizedSegments = segments.compactMap { item -> FlightSegment? in
            guard let dep = ServerPackageDateParser.dateTime(item.departureAt, airportCode: item.origin),
                  let arr = ServerPackageDateParser.dateTime(item.arrivalAt, airportCode: item.destination),
                  FlightReferenceCatalog.normalizedVerifiedFlightNumber(item.flightNumber) != nil else { return nil }
            let code = FlightReferenceCatalog.airlineCode(from: item.flightNumber) ?? item.airlineCode.uppercased()
            return FlightSegment(
                id: item.id,
                airline: FlightReferenceCatalog.airlineName(code: code, fallback: item.airline),
                airlineCode: code,
                flightNumber: item.flightNumber,
                origin: FlightAirportSnapshot(code: item.origin, terminal: item.originTerminal),
                destination: FlightAirportSnapshot(code: item.destination, terminal: item.destinationTerminal),
                departureAt: dep,
                arrivalAt: arr,
                durationMinutes: item.durationMinutes,
                aircraft: item.aircraft,
                operatingCarrier: item.operatingCarrier,
                cabin: item.cabin
            )
        }
        guard normalizedSegments.count == segments.count, normalizedSegments.count == stops + 1 else { return nil }
        let scope: FlightFareScope = fareScope == "totalParty" ? .totalParty : .perPassenger
        let connections = normalizedSegments.dropLast().map(\.destination)
        let value = LiveFlightCandidate(
            id: "server:\(id)",
            providerID: provider,
            providerName: providerConfig.displayName,
            direction: direction == "inbound" ? .inbound : .outbound,
            airline: FlightReferenceCatalog.airlineName(code: airlineCode, fallback: airline),
            flightNumber: flightNumber,
            origin: origin,
            destination: destination,
            departureAt: departure,
            arrivalAt: arrival,
            stops: stops,
            durationMinutes: durationMinutes,
            observedFare: fare,
            observedCurrency: "USD",
            fareScope: scope,
            observedAt: observed,
            sourceURL: sourceURL,
            rawTextFingerprint: "server-\(providerId)-\(flightNumber)-\(travelDate)",
            airlineCode: airlineCode,
            segments: normalizedSegments,
            connectionAirports: connections
        )
        return value.isDisplayableCandidate ? value : nil
    }

    private static func localDay(_ value: Date, airportCode: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = FlightReferenceCatalog.timeZone(for: airportCode)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    private static func isoDate(_ value: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

struct ConfiguredHotelComponentPrice: Decodable, Hashable {
    let ok: Bool
    let hotelId: String
    let roomId: String?
    let amount: Decimal
    let currency: String
    let unit: String
    let source: String
    let observedAt: String
}
