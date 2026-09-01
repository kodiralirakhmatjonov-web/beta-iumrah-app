import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum IgnavFlightProviderError: LocalizedError, Equatable {
    case invalidRequest
    case serverUnavailable
    case searchFailed

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Параметры поиска авиабилетов заполнены некорректно."
        case .serverUnavailable:
            return "Сервис поиска авиабилетов временно недоступен. Повторите попытку."
        case .searchFailed:
            return "Не удалось получить актуальные авиабилеты. Повторите поиск."
        }
    }
}

@MainActor
final class IgnavFlightInventoryProvider: FlightInventoryProviding {
    let sourceName = "Ignav"
    private let session: URLSession
    private let maxConcurrentDates = 3

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(
        request: FlightSearchRequest,
        dates: [Date],
        onUpdate: @escaping @MainActor ([LiveFlightCandidate]) -> Void
    ) async throws -> [LiveFlightCandidate] {
        guard !dates.isEmpty else { return [] }
        let session = self.session
        let indexed = dates.enumerated().map { ($0.offset, $0.element) }
        var nextIndex = 0
        var merged: [LiveFlightCandidate] = []
        var firstError: Error?

        await withTaskGroup(of: DateSearchResult.self) { group in
            func enqueue(_ item: (Int, Date)) {
                group.addTask {
                    do {
                        let values = try await Self.fetchDate(
                            session: session,
                            request: request,
                            date: item.1
                        )
                        return DateSearchResult(candidates: values, error: nil)
                    } catch {
                        return DateSearchResult(candidates: [], error: error)
                    }
                }
            }

            while nextIndex < min(maxConcurrentDates, indexed.count) {
                enqueue(indexed[nextIndex])
                nextIndex += 1
            }

            for await result in group {
                if firstError == nil, let error = result.error { firstError = error }
                if !result.candidates.isEmpty {
                    merged = Self.merge(merged, result.candidates)
                    onUpdate(merged)
                }
                if nextIndex < indexed.count {
                    enqueue(indexed[nextIndex])
                    nextIndex += 1
                }
            }
        }

        if merged.isEmpty, let firstError {
            throw firstError
        }
        return merged
    }

    private nonisolated static func fetchDate(
        session: URLSession,
        request: FlightSearchRequest,
        date: Date
    ) async throws -> [LiveFlightCandidate] {
        let url = AppConfig.apiBaseURL.appending(path: "api/package/flights/search")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 28
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(ProxySearchBody(request: request, date: date))

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw IgnavFlightProviderError.serverUnavailable }

        if http.statusCode == 503,
           let error = try? JSONDecoder().decode(ProxyErrorResponse.self, from: data),
           error.error == "FLIGHT_PROVIDER_NOT_CONFIGURED" {
            throw FlightInventoryProviderError.notConfigured
        }
        guard (200..<300).contains(http.statusCode) else {
            if (500..<600).contains(http.statusCode) { throw IgnavFlightProviderError.serverUnavailable }
            throw IgnavFlightProviderError.searchFailed
        }

        let decoded = try JSONDecoder().decode(ProxySearchResponse.self, from: data)
        guard decoded.ok, decoded.source == "ignav" else { throw IgnavFlightProviderError.searchFailed }
        let observedAt = try parseISO8601(decoded.observedAt)

        return decoded.itineraries.compactMap { itinerary in
            candidate(
                from: itinerary,
                request: request,
                expectedDate: date,
                observedAt: observedAt
            )
        }
    }

    private nonisolated static func candidate(
        from itinerary: ProxyItinerary,
        request: FlightSearchRequest,
        expectedDate: Date,
        observedAt: Date
    ) -> LiveFlightCandidate? {
        guard itinerary.price.status == "verified",
              itinerary.price.amount > 0,
              itinerary.price.currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil,
              !itinerary.segments.isEmpty else { return nil }

        let segments: [FlightSegment] = itinerary.segments.compactMap { value in
            guard value.marketingCarrierCode.range(of: "^[A-Z0-9]{2}$", options: .regularExpression) != nil,
                  value.flightNumber.range(of: "^[0-9]{1,4}[A-Z]?$", options: .regularExpression) != nil,
                  let departure = try? parseISO8601(value.departureTimeUTC),
                  let arrival = try? parseISO8601(value.arrivalTimeUTC),
                  departure < arrival,
                  value.durationMinutes > 0 else { return nil }
            return FlightSegment(
                id: "ignav:\(itinerary.ignavId):\(value.marketingCarrierCode)\(value.flightNumber):\(value.departureAirport)",
                airline: value.operatingCarrierName ?? itinerary.airline,
                airlineCode: value.marketingCarrierCode,
                flightNumber: "\(value.marketingCarrierCode) \(value.flightNumber)",
                origin: FlightAirportSnapshot(
                    code: value.departureAirport,
                    timeZoneIdentifier: value.departureTimezone
                ),
                destination: FlightAirportSnapshot(
                    code: value.arrivalAirport,
                    timeZoneIdentifier: value.arrivalTimezone
                ),
                departureAt: departure,
                arrivalAt: arrival,
                durationMinutes: value.durationMinutes,
                aircraft: value.aircraft,
                operatingCarrier: value.operatingCarrierName,
                cabin: itinerary.cabinClass
            )
        }
        guard segments.count == itinerary.segments.count,
              let first = segments.first,
              let last = segments.last,
              first.origin.code == request.origin,
              last.destination.code == request.destination,
              itinerary.stops == segments.count - 1,
              itinerary.durationMinutes > 0 else { return nil }

        let expected = calendarDay(expectedDate)
        let actual = calendarDay(first.departureAt, timeZoneIdentifier: first.origin.timeZoneIdentifier)
        guard expected == actual else { return nil }

        for segment in segments {
            guard let originZone = segment.origin.timeZoneIdentifier, TimeZone(identifier: originZone) != nil,
                  let destinationZone = segment.destination.timeZoneIdentifier, TimeZone(identifier: destinationZone) != nil else { return nil }
        }
        for index in 1..<segments.count {
            guard segments[index - 1].destination.code == segments[index].origin.code,
                  segments[index - 1].arrivalAt <= segments[index].departureAt else { return nil }
        }

        let connections = segments.count > 1
            ? segments.dropLast().map { $0.destination }
            : []
        let scope: FlightFareScope = itinerary.fareScope == "total_party" ? .totalParty : .unknown
        guard scope != .unknown else { return nil }

        let candidate = LiveFlightCandidate(
            id: "ignav:\(itinerary.ignavId):\(request.direction.rawValue)",
            sourceID: "ignav",
            sourceName: "Ignav",
            direction: request.direction,
            airline: itinerary.airline,
            flightNumber: itinerary.flightNumber,
            origin: itinerary.origin,
            destination: itinerary.destination,
            departureAt: first.departureAt,
            arrivalAt: last.arrivalAt,
            stops: itinerary.stops,
            durationMinutes: itinerary.durationMinutes,
            observedFare: itinerary.price.amount,
            observedCurrency: itinerary.price.currency,
            fareScope: scope,
            observedAt: observedAt,
            sourceURL: nil,
            rawFingerprint: itinerary.ignavId,
            airlineCode: itinerary.airlineCode,
            segments: segments,
            connectionAirports: connections.isEmpty ? nil : connections,
            providerItineraryID: itinerary.ignavId,
            cabinClass: itinerary.cabinClass,
            baggage: itinerary.bags.map { FlightBaggageAllowance(carryOn: $0.carryOn, checked: $0.checked) },
            requiresSelfTransfer: itinerary.requiresSelfTransfer
        )
        return candidate.isDisplayableCandidate ? candidate : nil
    }

    private nonisolated static func merge(_ lhs: [LiveFlightCandidate], _ rhs: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var result = lhs
        var keys = Set(result.map(\.deduplicationKey))
        for value in rhs where keys.insert(value.deduplicationKey).inserted {
            result.append(value)
        }
        return result
    }

    private nonisolated static func parseISO8601(_ value: String) throws -> Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: value) { return date }
        throw IgnavFlightProviderError.searchFailed
    }

    private nonisolated static func calendarDay(_ date: Date, timeZoneIdentifier: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let timeZoneIdentifier, let zone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = zone
        } else {
            // The user selects a calendar day in the device locale. Preserve that
            // calendar day when building the API request; converting local midnight
            // to UTC can shift Uzbekistan dates to the previous day.
            formatter.timeZone = .current
        }
        return formatter.string(from: date)
    }
}

private struct DateSearchResult: Sendable {
    let candidates: [LiveFlightCandidate]
    let error: Error?
}

private struct ProxySearchBody: Encodable, Sendable {
    let direction: String
    let origin: String
    let destination: String
    let departureDate: String
    let adults: Int
    let children: Int
    let infantsInSeat: Int
    let infantsOnLap: Int
    let cabinClass: String
    let maxStops: Int?
    let minCarryOnBags: Int?
    let minCheckedBags: Int?
    let maxPrice: Int?
    let departureTimeRange: ProxyTimeRange?
    let airlinesInclude: [String]?
    let airlinesExclude: [String]?
    let allowSelfTransfer: Bool

    init(request: FlightSearchRequest, date: Date) {
        let filters = request.filters
        direction = request.direction.rawValue
        origin = request.origin
        destination = request.destination
        departureDate = Self.day(date)
        adults = request.adults
        children = request.children
        if filters.infantSeating == .lap {
            infantsOnLap = min(request.infants, request.adults)
            infantsInSeat = max(0, request.infants - request.adults)
        } else {
            infantsOnLap = 0
            infantsInSeat = request.infants
        }
        cabinClass = filters.cabinClass.rawValue
        maxStops = filters.stops.maxStops
        minCarryOnBags = filters.minCarryOnBags > 0 ? filters.minCarryOnBags : nil
        minCheckedBags = filters.minCheckedBags > 0 ? filters.minCheckedBags : nil
        maxPrice = filters.maxPriceUSD.flatMap { $0 > 0 ? $0 : nil }
        departureTimeRange = ProxyTimeRange(departure: filters.departureWindow, arrival: filters.arrivalWindow)
        let include = filters.normalizedAirlinesInclude
        let exclude = filters.normalizedAirlinesExclude.filter { !include.contains($0) }
        airlinesInclude = include.isEmpty ? nil : include
        airlinesExclude = exclude.isEmpty ? nil : exclude
        allowSelfTransfer = filters.allowSelfTransfer
    }

    enum CodingKeys: String, CodingKey {
        case direction, origin, destination, adults, children
        case departureDate = "departure_date"
        case infantsInSeat = "infants_in_seat"
        case infantsOnLap = "infants_on_lap"
        case cabinClass = "cabin_class"
        case maxStops = "max_stops"
        case minCarryOnBags = "min_carry_on_bags"
        case minCheckedBags = "min_checked_bags"
        case maxPrice = "max_price"
        case departureTimeRange = "departure_time_range"
        case airlinesInclude = "airlines_include"
        case airlinesExclude = "airlines_exclude"
        case allowSelfTransfer = "allow_self_transfer"
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Trip dates are calendar-day values selected by the user. Encode them in
        // the current calendar timezone so a local midnight never becomes the
        // previous UTC date before it reaches Ignav.
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct ProxyTimeRange: Encodable, Sendable {
    let earliestHour: Int?
    let latestHour: Int?
    let arrivalEarliestHour: Int?
    let arrivalLatestHour: Int?

    init?(departure: FlightTimeWindow, arrival: FlightTimeWindow) {
        earliestHour = departure.hours?.lowerBound
        latestHour = departure.hours?.upperBound
        arrivalEarliestHour = arrival.hours?.lowerBound
        arrivalLatestHour = arrival.hours?.upperBound
        if earliestHour == nil, latestHour == nil, arrivalEarliestHour == nil, arrivalLatestHour == nil { return nil }
    }

    enum CodingKeys: String, CodingKey {
        case earliestHour = "earliest_hour"
        case latestHour = "latest_hour"
        case arrivalEarliestHour = "arrival_earliest_hour"
        case arrivalLatestHour = "arrival_latest_hour"
    }
}

private struct ProxyErrorResponse: Decodable { let error: String }
private struct ProxySearchResponse: Decodable {
    let ok: Bool
    let source: String
    let observedAt: String
    let itineraries: [ProxyItinerary]
    enum CodingKeys: String, CodingKey {
        case ok, source, itineraries
        case observedAt = "observed_at"
    }
}
private struct ProxyPrice: Decodable {
    let amount: Decimal
    let currency: String
    let status: String
}
private struct ProxyBags: Decodable {
    let carryOn: Int?
    let checked: Int?
    enum CodingKeys: String, CodingKey { case carryOn = "carry_on"; case checked }
}
private struct ProxySegment: Decodable {
    let marketingCarrierCode: String
    let flightNumber: String
    let operatingCarrierName: String?
    let departureAirport: String
    let departureTimeLocal: String
    let departureTimezone: String?
    let departureTimeUTC: String
    let arrivalAirport: String
    let arrivalTimeLocal: String
    let arrivalTimezone: String?
    let arrivalTimeUTC: String
    let durationMinutes: Int
    let aircraft: String?

    enum CodingKeys: String, CodingKey {
        case marketingCarrierCode = "marketing_carrier_code"
        case flightNumber = "flight_number"
        case operatingCarrierName = "operating_carrier_name"
        case departureAirport = "departure_airport"
        case departureTimeLocal = "departure_time_local"
        case departureTimezone = "departure_timezone"
        case departureTimeUTC = "departure_time_utc"
        case arrivalAirport = "arrival_airport"
        case arrivalTimeLocal = "arrival_time_local"
        case arrivalTimezone = "arrival_timezone"
        case arrivalTimeUTC = "arrival_time_utc"
        case durationMinutes = "duration_minutes"
        case aircraft
    }
}
private struct ProxyItinerary: Decodable {
    let price: ProxyPrice
    let airline: String
    let flightNumber: String
    let airlineCode: String
    let origin: String
    let destination: String
    let durationMinutes: Int
    let stops: Int
    let cabinClass: String?
    let bags: ProxyBags?
    let requiresSelfTransfer: Bool?
    let fareScope: String
    let ignavId: String
    let segments: [ProxySegment]

    enum CodingKeys: String, CodingKey {
        case price, airline, origin, destination, stops, bags, segments
        case flightNumber = "flight_number"
        case airlineCode = "airline_code"
        case durationMinutes = "duration_minutes"
        case cabinClass = "cabin_class"
        case requiresSelfTransfer = "requires_self_transfer"
        case fareScope = "fare_scope"
        case ignavId = "ignav_id"
    }
}
