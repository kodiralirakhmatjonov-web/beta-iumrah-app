import Foundation

enum FlightTextParser {
    static func candidates(
        blocks: [String],
        provider: FlightBotProvider,
        request: FlightBotSearchRequest,
        sourceURL: URL,
        observedAt: Date = Date()
    ) -> [LiveFlightCandidate] {
        blocks.compactMap { block in
            parse(block: block, provider: provider, request: request, sourceURL: sourceURL, observedAt: observedAt)
        }
    }

    private static func parse(
        block: String,
        provider: FlightBotProvider,
        request: FlightBotSearchRequest,
        sourceURL: URL,
        observedAt: Date
    ) -> LiveFlightCandidate? {
        guard let fare = parseFare(block, provider: provider) else { return nil }

        let normalizedBlock = block.replacingOccurrences(of: "\u{00a0}", with: " ")
        let times = matches(pattern: #"\b(?:[01]?\d|2[0-3]):[0-5]\d\b"#, in: normalizedBlock)
        guard times.count >= 2 else { return nil }

        let rawFlightNumbers = matches(pattern: #"\b[A-Z0-9]{2,3}[\s-]?\d{1,4}\b"#, in: normalizedBlock.uppercased())
        let currencyPrefixes: Set<String> = ["USD", "UZS", "EUR", "RUB", "SAR", "AED", "TRY", "KZT", "GBP"]
        let flightNumbers = deduplicate(rawFlightNumbers.map(normalizeFlightNumber)).filter { number in
            let firstToken = number.uppercased().split(separator: " ").first.map(String.init) ?? ""
            guard !currencyPrefixes.contains(firstToken) else { return false }
            let code = FlightReferenceCatalog.airlineCode(from: number)
            guard let code, code.range(of: "^[A-Z0-9]{2}$", options: .regularExpression) != nil else { return false }
            if FlightReferenceCatalog.airline(code: code) != nil || code == providerCode(provider.id) { return true }
            return provider.id == .googleFlights || provider.id == .skyscanner
        }
        guard let primaryFlightNumber = flightNumbers.first else { return nil }
        let primaryAirlineCode = FlightReferenceCatalog.airlineCode(from: primaryFlightNumber) ?? providerCode(provider.id)
        let airline = inferredAirline(from: normalizedBlock, flightNumber: primaryFlightNumber, provider: provider)

        let inferredAirportCodes = airportSequence(
            from: normalizedBlock,
            origin: request.origin,
            destination: request.destination,
            expectedSegments: max(1, flightNumbers.count)
        )
        let declaredStops = inferredStops(from: normalizedBlock)
        let segmentCount = resolvedSegmentCount(
            flightNumbers: flightNumbers,
            times: times,
            airportCodes: inferredAirportCodes,
            declaredStops: declaredStops
        )

        let segments = buildSegments(
            block: normalizedBlock,
            request: request,
            provider: provider,
            airline: airline,
            primaryAirlineCode: primaryAirlineCode,
            flightNumbers: flightNumbers,
            times: times,
            airportCodes: inferredAirportCodes,
            segmentCount: segmentCount
        )

        let departure: Date
        let arrival: Date
        let duration: Int
        let stops: Int

        if let first = segments.first, let last = segments.last {
            departure = first.departureAt
            arrival = last.arrivalAt
            duration = max(0, Int(arrival.timeIntervalSince(departure) / 60))
            stops = max(declaredStops, segments.count - 1)
        } else {
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: request.date)
            guard let parsedDeparture = combine(day: day, hhmm: times[0], airportCode: request.origin, fallbackCalendar: calendar) else { return nil }
            var parsedArrival = combine(day: day, hhmm: times[1], airportCode: request.destination, fallbackCalendar: calendar) ?? parsedDeparture
            while parsedArrival < parsedDeparture {
                parsedArrival = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: parsedArrival) ?? parsedArrival
            }
            departure = parsedDeparture
            arrival = parsedArrival
            duration = max(0, Int(arrival.timeIntervalSince(departure) / 60))
            stops = declaredStops
        }

        return LiveFlightCandidate(
            id: UUID().uuidString,
            providerID: provider.id,
            providerName: provider.displayName,
            direction: request.direction,
            airline: airline,
            flightNumber: primaryFlightNumber,
            origin: request.origin,
            destination: request.destination,
            departureAt: departure,
            arrivalAt: arrival,
            stops: stops,
            durationMinutes: duration,
            observedFare: fare.amount,
            observedCurrency: fare.currency,
            fareScope: fare.scope,
            observedAt: observedAt,
            sourceURL: sourceURL.absoluteString,
            rawTextFingerprint: stableFingerprint(normalizedBlock),
            airlineCode: primaryAirlineCode,
            segments: segments
        )
    }

    private static func resolvedSegmentCount(
        flightNumbers: [String],
        times: [String],
        airportCodes: [String],
        declaredStops: Int
    ) -> Int {
        let fromFlights = flightNumbers.isEmpty ? 0 : flightNumbers.count
        let fromTimes = times.count / 2
        let fromAirports = max(0, airportCodes.count - 1)
        let declared = declaredStops + 1
        let candidates = [fromFlights, fromTimes, fromAirports, declared].filter { $0 > 0 }
        return max(1, min(candidates.max() ?? 1, 4))
    }

    private static func buildSegments(
        block: String,
        request: FlightBotSearchRequest,
        provider: FlightBotProvider,
        airline: String,
        primaryAirlineCode: String,
        flightNumbers: [String],
        times: [String],
        airportCodes: [String],
        segmentCount: Int
    ) -> [FlightSegment] {
        guard times.count >= segmentCount * 2 else { return [] }

        var routeCodes = airportCodes
        if routeCodes.first != request.origin { routeCodes.insert(request.origin, at: 0) }
        if routeCodes.last != request.destination { routeCodes.append(request.destination) }
        routeCodes = collapseAdjacentDuplicates(routeCodes)
        guard routeCodes.count >= segmentCount + 1 else { return [] }

        let operatingCarrier = inferredOperatingCarrier(from: block)
        let cabin = inferredCabin(from: block, fallback: request.cabin)
        let allAircrafts = inferredAircrafts(from: block)

        var result: [FlightSegment] = []
        var previousArrival: Date?

        for index in 0..<segmentCount {
            let originCode = routeCodes[index]
            let destinationCode = routeCodes[index + 1]
            let number = flightNumbers.indices.contains(index) ? flightNumbers[index] : (flightNumbers.first ?? providerCode(provider.id))
            let code = FlightReferenceCatalog.airlineCode(from: number) ?? primaryAirlineCode
            let segmentAirline = FlightReferenceCatalog.airlineName(code: code, fallback: airline)

            guard var departure = localDate(on: request.date, hhmm: times[index * 2], airportCode: originCode),
                  var arrival = localDate(on: request.date, hhmm: times[index * 2 + 1], airportCode: destinationCode) else {
                return []
            }

            if let previousArrival {
                while departure < previousArrival {
                    departure = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: departure) ?? departure
                }
            }
            while arrival < departure {
                arrival = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: arrival) ?? arrival
            }

            let departureTerminal = inferredTerminal(for: originCode, in: block)
            let arrivalTerminal = inferredTerminal(for: destinationCode, in: block)
            let aircraft: String?
            if allAircrafts.count == segmentCount, allAircrafts.indices.contains(index) {
                aircraft = allAircrafts[index]
            } else if segmentCount == 1 {
                aircraft = allAircrafts.first
            } else {
                aircraft = nil
            }

            result.append(
                FlightSegment(
                    airline: segmentAirline,
                    airlineCode: code,
                    flightNumber: number,
                    origin: FlightAirportSnapshot(code: originCode, terminal: departureTerminal),
                    destination: FlightAirportSnapshot(code: destinationCode, terminal: arrivalTerminal),
                    departureAt: departure,
                    arrivalAt: arrival,
                    durationMinutes: max(0, Int(arrival.timeIntervalSince(departure) / 60)),
                    aircraft: aircraft,
                    operatingCarrier: operatingCarrier,
                    cabin: cabin
                )
            )
            previousArrival = arrival
        }

        return result
    }

    private static func airportSequence(from text: String, origin: String, destination: String, expectedSegments: Int) -> [String] {
        let ignored: Set<String> = [
            "USD", "UZS", "EUR", "RUB", "SAR", "AED", "TRY", "KZT", "GBP",
            "FROM", "TO", "THE", "AND", "INT", "AIR", "MAX"
        ]
        let explicitCodes = matches(pattern: #"\b[A-Z]{3}\b"#, in: text.uppercased())
            .filter { !ignored.contains($0) }
        let mentionedCodes = FlightReferenceCatalog.airportMentions(in: text)
        let codes = explicitCodes.count >= 2 ? explicitCodes : mentionedCodes
        var sequence = collapseAdjacentDuplicates(codes)

        // Require route anchors. This prevents unrelated three-letter words in
        // airline marketing copy from becoming fake airports.
        if let originIndex = sequence.firstIndex(of: origin) {
            sequence = Array(sequence[originIndex...])
        }
        if let destinationIndex = sequence.lastIndex(of: destination) {
            sequence = Array(sequence[...destinationIndex])
        }

        if sequence.first != origin { sequence.insert(origin, at: 0) }
        if sequence.last != destination { sequence.append(destination) }

        // Keep only a plausible route path. A four-segment itinerary needs at
        // most five airports.
        let maximum = min(5, max(2, expectedSegments + 1))
        if sequence.count > maximum {
            let intermediates = Array(sequence.dropFirst().dropLast().prefix(maximum - 2))
            sequence = [origin] + intermediates + [destination]
        }
        return collapseAdjacentDuplicates(sequence)
    }

    private static func parseFare(_ text: String, provider: FlightBotProvider) -> (amount: Decimal, currency: String, scope: FlightFareScope)? {
        let patterns: [(String, String)] = [
            (#"\$\s*([0-9][0-9\s,.]*)"#, "USD"),
            (#"USD\s*([0-9][0-9\s,.]*)"#, "USD"),
            (#"([0-9][0-9\s,.]*)\s*USD"#, "USD"),
            (#"UZS\s*([0-9][0-9\s,.]*)"#, "UZS"),
            (#"([0-9][0-9\s,.]*)\s*UZS"#, "UZS"),
            (#"([0-9][0-9\s,.]*)\s*(?:so['’]?m|сум)"#, "UZS"),
            (#"€\s*([0-9][0-9\s,.]*)"#, "EUR"),
            (#"EUR\s*([0-9][0-9\s,.]*)"#, "EUR"),
            (#"₽\s*([0-9][0-9\s,.]*)"#, "RUB"),
            (#"RUB\s*([0-9][0-9\s,.]*)"#, "RUB"),
            (#"SAR\s*([0-9][0-9\s,.]*)"#, "SAR"),
            (#"AED\s*([0-9][0-9\s,.]*)"#, "AED"),
            (#"([0-9][0-9\s,.]*)\s*AED"#, "AED"),
            (#"TRY\s*([0-9][0-9\s,.]*)"#, "TRY"),
            (#"KZT\s*([0-9][0-9\s,.]*)"#, "KZT"),
            (#"GBP\s*([0-9][0-9\s,.]*)"#, "GBP")
        ]

        for (pattern, currency) in patterns {
            guard let capture = firstCapture(pattern: pattern, in: text) else { continue }
            let normalized = capture.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: "")
            guard let decimal = Decimal(string: normalized), decimal > 0 else { continue }
            let lower = text.lowercased()
            let totalMarkers = ["total", "итого", "за всех", "total fare", "grand total", "jami"]
            let passengerMarkers = ["per passenger", "per person", "/ person", "за пассажира", "на пассажира", "1 adult", "from "]
            let scope: FlightFareScope
            if totalMarkers.contains(where: { lower.contains($0) }) {
                scope = .totalParty
            } else if passengerMarkers.contains(where: { lower.contains($0) }) {
                scope = .perPassenger
            } else {
                scope = provider.defaultFareScope
            }
            return (decimal, currency, scope)
        }
        return nil
    }

    private static func inferredAirline(from block: String, flightNumber: String, provider: FlightBotProvider) -> String {
        let known = [
            "Uzbekistan Airways", "Qanot Sharq", "Centrum Air", "Silk Avia", "Air Samarkand", "Fly Khiva",
            "AJet", "Flynas", "flynas", "Saudia", "Turkish Airlines", "Qatar Airways", "Emirates", "Air Arabia",
            "Jazeera Airways", "Wizz Air", "Azerbaijan Airlines", "Pegasus", "flydubai", "Air Astana", "FlyArystan"
        ]
        if let explicit = known.first(where: { block.localizedCaseInsensitiveContains($0) }) {
            return explicit
        }

        let code = FlightReferenceCatalog.airlineCode(from: flightNumber)
        if let reference = FlightReferenceCatalog.airline(code: code) { return reference.name }
        if provider.marketScope == .uzbekistanPriority || provider.marketScope == .regional { return provider.displayName }

        // Never present a metasearch provider as if it were the airline.
        if provider.id == .skyscanner || provider.id == .googleFlights {
            return "Airline"
        }
        return provider.displayName
    }

    private static func inferredStops(from block: String) -> Int {
        let lower = block.lowercased()
        if lower.contains("nonstop") || lower.contains("non-stop") || lower.contains("direct") || lower.contains("прям") || lower.contains("to‘g‘ridan") { return 0 }
        if let count = firstCapture(pattern: #"([1-9])\s*(?:stop|stops|пересад|to['’‘]?xtash)"#, in: lower), let value = Int(count) { return value }
        let currencyPrefixes: Set<String> = ["USD", "UZS", "EUR", "RUB", "SAR", "AED", "TRY", "KZT", "GBP"]
        let flightCount = deduplicate(matches(pattern: #"\b[A-Z0-9]{2,3}[\s-]?\d{1,4}\b"#, in: block.uppercased())
            .map(normalizeFlightNumber)
            .filter { number in
                let firstToken = number.uppercased().split(separator: " ").first.map(String.init) ?? ""
                return !currencyPrefixes.contains(firstToken) && FlightReferenceCatalog.airline(code: FlightReferenceCatalog.airlineCode(from: number)) != nil
            }).count
        return max(0, min(3, flightCount - 1))
    }

    private static func inferredAircrafts(from text: String) -> [String] {
        let descriptive = matches(
            pattern: #"\b(?:Boeing\s*7\d{2}(?:[- ]?(?:MAX\s*[89]|800|900|300ER))?|Airbus\s*A3\d{2}(?:neo)?|ATR\s*72(?:-\d{3})?|Embraer\s*E?\d{3})\b"#,
            in: text
        )
        let output = descriptive.compactMap(FlightReferenceCatalog.aircraftName(from:))
        if !output.isEmpty { return output }
        let equipmentCodes = matches(pattern: #"\b(?:7M8|7M9|738|739|737|32N|32Q|320|321|319|359|789|788|77W|763|AT7|E190|E195)\b"#, in: text.uppercased())
        return equipmentCodes.compactMap(FlightReferenceCatalog.aircraftName(from:))
    }

    private static func inferredTerminal(for airportCode: String, in text: String) -> String? {
        guard let terminalRegex = try? NSRegularExpression(
            pattern: #"(?:terminal|терминал|терминали)\s*([A-Z0-9]+)"#,
            options: [.caseInsensitive]
        ), let airportRegex = try? NSRegularExpression(pattern: #"\b[A-Z]{3}\b"#) else { return nil }

        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let airportMatches = airportRegex.matches(in: text.uppercased(), range: fullRange).compactMap { match -> (String, Int)? in
            guard match.range.location != NSNotFound else { return nil }
            let code = ns.substring(with: match.range).uppercased()
            guard FlightReferenceCatalog.airport(code) != nil else { return nil }
            return (code, match.range.location)
        }
        guard !airportMatches.isEmpty else { return nil }

        for terminalMatch in terminalRegex.matches(in: text, range: fullRange) {
            guard terminalMatch.numberOfRanges > 1, terminalMatch.range(at: 1).location != NSNotFound else { continue }
            let terminalPosition = terminalMatch.range.location
            guard let nearest = airportMatches.min(by: { abs($0.1 - terminalPosition) < abs($1.1 - terminalPosition) }),
                  nearest.0 == airportCode.uppercased() else { continue }
            return ns.substring(with: terminalMatch.range(at: 1))
        }
        return nil
    }

    private static func inferredOperatingCarrier(from text: String) -> String? {
        let patterns = [
            #"operated by\s+([A-Za-z][A-Za-z .'-]{2,40})"#,
            #"выполняется\s+([A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё .'-]{2,40})"#
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern: pattern, in: text) {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func inferredCabin(from text: String, fallback: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("business") || lower.contains("бизнес") { return "business" }
        if lower.contains("premium economy") { return "premium_economy" }
        if lower.contains("first class") || lower.contains("первый класс") { return "first" }
        if lower.contains("economy") || lower.contains("эконом") { return "economy" }
        return fallback.isEmpty ? nil : fallback
    }

    private static func providerCode(_ id: FlightBotProviderID) -> String {
        switch id {
        case .uzbekistanAirways: return "HY"
        case .qanotSharq: return "HH"
        case .centrumAir: return "C6"
        case .silkAvia: return "US"
        case .airSamarkand: return "9S"
        case .flyKhiva: return "2U"
        case .flynas: return "XY"
        case .saudia: return "SV"
        case .turkishAirlines: return "TK"
        case .airArabia: return "G9"
        case .jazeeraAirways: return "J9"
        case .flydubai: return "FZ"
        case .airAstana: return "KC"
        case .flyArystan: return "FS"
        case .googleFlights: return "GF"
        case .skyscanner: return "SKY"
        }
    }

    private static func localDate(on day: Date, hhmm: String, airportCode: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = FlightReferenceCatalog.timeZone(for: airportCode) ?? .current
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard timeParts.count == 2 else { return nil }
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = dayParts.year
        components.month = dayParts.month
        components.day = dayParts.day
        components.hour = timeParts[0]
        components.minute = timeParts[1]
        return calendar.date(from: components)
    }

    private static func combine(day: Date, hhmm: String, airportCode: String, fallbackCalendar: Calendar) -> Date? {
        localDate(on: day, hhmm: hhmm, airportCode: airportCode) ?? {
            let parts = hhmm.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return fallbackCalendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
        }()
    }

    private static func normalizeFlightNumber(_ value: String) -> String {
        let cleaned = value.uppercased().replacingOccurrences(of: "-", with: " ").split(separator: " ").joined(separator: " ")
        if cleaned.contains(" ") { return cleaned }
        let letters = cleaned.prefix { $0.isLetter || $0.isNumber }
        let prefix = String(letters.prefix(2))
        let suffix = String(cleaned.dropFirst(min(2, cleaned.count)))
        return suffix.isEmpty ? cleaned : "\(prefix) \(suffix)"
    }

    private static func collapseAdjacentDuplicates(_ values: [String]) -> [String] {
        var output: [String] = []
        for value in values where output.last != value { output.append(value) }
        return output
    }

    private static func deduplicate<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.range.location != NSNotFound else { return nil }
            return ns.substring(with: match.range)
        }
    }

    private static func captures(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { return nil }
            return ns.substring(with: match.range(at: 1))
        }
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        captures(pattern: pattern, in: text).first
    }

    private static func stableFingerprint(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
