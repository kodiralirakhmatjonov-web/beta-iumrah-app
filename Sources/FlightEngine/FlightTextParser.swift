import Foundation

enum FlightTextParser {
    static func candidates(
        blocks: [String],
        provider: FlightBotProvider,
        request: FlightBotSearchRequest,
        sourceURL: URL,
        requirement: FlightCandidateRequirement = .displayable,
        observedAt: Date = Date()
    ) -> [LiveFlightCandidate] {
        blocks.compactMap { block in
            parse(
                block: block,
                provider: provider,
                request: request,
                sourceURL: sourceURL,
                requirement: requirement,
                observedAt: observedAt
            )
        }
    }

    private static func parse(
        block: String,
        provider: FlightBotProvider,
        request: FlightBotSearchRequest,
        sourceURL: URL,
        requirement: FlightCandidateRequirement,
        observedAt: Date
    ) -> LiveFlightCandidate? {
        guard let fare = parseFare(block, provider: provider) else { return nil }

        let normalizedBlock = block.replacingOccurrences(of: "\u{00a0}", with: " ")
        let times = extractTimes(from: normalizedBlock)
        guard times.count >= 2 else { return nil }

        if requirement == .pricingReference {
            return parsePricingReference(
                block: normalizedBlock,
                provider: provider,
                request: request,
                sourceURL: sourceURL,
                observedAt: observedAt,
                fare: fare,
                times: times
            )
        }

        guard hasRouteEvidence(in: normalizedBlock, origin: request.origin, destination: request.destination) else {
            return nil
        }

        // A real flight number always has a carrier code containing at least one
        // letter. Numeric fragments such as "23 2" or "24 9" are never accepted.
        let rawFlightNumbers = matches(
            pattern: #"\b(?:[A-Z][A-Z0-9]|[0-9][A-Z])[\s-]?\d{1,4}\b"#,
            in: normalizedBlock.uppercased()
        )
        let flightNumbers = deduplicate(rawFlightNumbers.map(normalizeFlightNumber)).filter { number in
            guard let code = FlightReferenceCatalog.airlineCode(from: number) else { return false }
            return FlightReferenceCatalog.airline(code: code) != nil
        }
        guard let primaryFlightNumber = flightNumbers.first,
              let primaryAirlineCode = FlightReferenceCatalog.airlineCode(from: primaryFlightNumber),
              let airlineReference = FlightReferenceCatalog.airline(code: primaryAirlineCode) else { return nil }
        let airline = airlineReference.name

        let inferredAirportCodes = airportSequence(
            from: normalizedBlock,
            origin: request.origin,
            destination: request.destination,
            expectedSegments: max(1, flightNumbers.count)
        )
        let explicitStops = inferredStops(from: normalizedBlock)
        let evidenceStops = max(max(0, flightNumbers.count - 1), max(0, inferredAirportCodes.count - 2))
        // One confirmed flight number tied to the requested origin/destination is
        // itself a factual single-leg itinerary. For connections we still require
        // concrete stop/segment evidence; we never manufacture a transfer city.
        let confirmedSingleLeg = flightNumbers.count == 1 && evidenceStops == 0
        guard explicitStops != nil || evidenceStops > 0 || confirmedSingleLeg else { return nil }
        let stops = max(explicitStops ?? 0, evidenceStops)
        guard stops <= 3 else { return nil }

        // Direct flights are accepted with one confirmed flight number and the
        // source departure/arrival times. Connections stay strict: every leg must
        // expose its own flight number, intermediate airport and local times. This
        // keeps transfer-city/country data factual without throwing away valid
        // nonstop results merely because a provider omitted a duration label.
        let segmentCount = stops + 1
        if stops == 0 {
            guard flightNumbers.count >= 1, times.count >= 2 else { return nil }
        } else {
            guard flightNumbers.count >= segmentCount else { return nil }
            guard times.count >= segmentCount * 2 else { return nil }
        }

        let selectedFlightNumbers = Array(flightNumbers.prefix(segmentCount))
        let detailedRoute = stops == 0 ? nil : routeCodesByFlightNumbers(
            in: normalizedBlock,
            flightNumbers: selectedFlightNumbers,
            origin: request.origin,
            destination: request.destination
        )
        if stops > 0 {
            guard (detailedRoute?.count ?? inferredAirportCodes.count) >= segmentCount + 1 else { return nil }
        }
        let resolvedRoute = stops == 0 ? [request.origin, request.destination] : (detailedRoute ?? inferredAirportCodes)
        let resolvedTimes = segmentTimes(
            from: normalizedBlock,
            flightNumbers: selectedFlightNumbers,
            routeCodes: resolvedRoute,
            fallback: times,
            segmentCount: segmentCount
        )
        guard resolvedTimes.count >= segmentCount * 2 else { return nil }

        let segments = buildSegments(
            block: normalizedBlock,
            request: request,
            provider: provider,
            airline: airline,
            primaryAirlineCode: primaryAirlineCode,
            flightNumbers: selectedFlightNumbers,
            times: resolvedTimes,
            airportCodes: resolvedRoute,
            segmentCount: segmentCount
        )
        guard segments.count == segmentCount,
              let departure = segments.first?.departureAt,
              let arrival = segments.last?.arrivalAt else { return nil }
        let duration = explicitDurationMinutes(from: normalizedBlock) ?? 0

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

    private static func parsePricingReference(
        block: String,
        provider: FlightBotProvider,
        request: FlightBotSearchRequest,
        sourceURL: URL,
        observedAt: Date,
        fare: (amount: Decimal, currency: String, scope: FlightFareScope),
        times: [String]
    ) -> LiveFlightCandidate? {
        guard let departure = localDate(on: request.date, hhmm: times[0], airportCode: request.origin),
              var arrival = localDate(on: request.date, hhmm: times[1], airportCode: request.destination) else { return nil }
        while arrival < departure {
            arrival = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: arrival) ?? arrival
        }

        let routeCodes = airportSequence(from: block, origin: request.origin, destination: request.destination, expectedSegments: 1)
        let evidenceStops = max(0, routeCodes.count - 2)
        let stops = max(inferredStops(from: block) ?? 0, evidenceStops)
        let airlineName = inferredReferenceAirline(from: block, provider: provider)
        let referenceNumber = "REF-\(provider.id.rawValue)"

        return LiveFlightCandidate(
            id: UUID().uuidString,
            providerID: provider.id,
            providerName: provider.displayName,
            direction: request.direction,
            airline: airlineName,
            flightNumber: referenceNumber,
            origin: request.origin,
            destination: request.destination,
            departureAt: departure,
            arrivalAt: arrival,
            stops: min(3, stops),
            durationMinutes: explicitDurationMinutes(from: block) ?? 0,
            observedFare: fare.amount,
            observedCurrency: fare.currency,
            fareScope: fare.scope,
            observedAt: observedAt,
            sourceURL: sourceURL.absoluteString,
            rawTextFingerprint: stableFingerprint(block),
            airlineCode: nil,
            segments: nil
        )
    }

    private static func hasRouteEvidence(in text: String, origin: String, destination: String) -> Bool {
        let explicitCodes = Set(matches(pattern: #"\b[A-Z]{3}\b"#, in: text.uppercased()))
        let mentioned = Set(FlightReferenceCatalog.airportMentions(in: text))
        let hasOrigin = explicitCodes.contains(origin.uppercased()) || mentioned.contains(origin.uppercased())
        let hasDestination = explicitCodes.contains(destination.uppercased()) || mentioned.contains(destination.uppercased())
        return hasOrigin && hasDestination
    }

    private static func inferredReferenceAirline(from block: String, provider: FlightBotProvider) -> String {
        let names = [
            "Uzbekistan Airways", "Qanot Sharq", "Centrum Air", "Silk Avia", "Air Samarkand", "Fly Khiva",
            "AJet", "flynas", "Saudia", "Turkish Airlines", "Qatar Airways", "Emirates", "Air Arabia",
            "Jazeera Airways", "Azerbaijan Airlines", "Pegasus Airlines", "flydubai", "Air Astana", "FlyArystan",
            "Wizz Air", "Etihad Airways", "Oman Air", "Gulf Air", "Kuwait Airways", "EgyptAir"
        ]
        return names.first(where: { block.localizedCaseInsensitiveContains($0) }) ?? provider.displayName
    }

    private static func routeCodesByFlightNumbers(
        in text: String,
        flightNumbers: [String],
        origin: String,
        destination: String
    ) -> [String]? {
        guard flightNumbers.count > 1 else { return nil }
        let uppercase = text.uppercased()
        let ns = uppercase as NSString
        guard let airportRegex = try? NSRegularExpression(pattern: #"\b[A-Z]{3}\b"#) else { return nil }

        let airportMatches: [(code: String, range: NSRange)] = airportRegex.matches(
            in: uppercase,
            range: NSRange(location: 0, length: ns.length)
        ).compactMap { match in
            guard match.range.location != NSNotFound else { return nil }
            let code = ns.substring(with: match.range)
            guard FlightReferenceCatalog.airport(code) != nil else { return nil }
            return (code, match.range)
        }

        var route = [origin.uppercased()]
        var expectedOrigin = origin.uppercased()
        var previousFlightEnd = 0

        for (index, number) in flightNumbers.enumerated() {
            guard let flightRange = rangeOfFlightNumber(number, in: uppercase) else { return nil }
            let nextFlightStart: Int = {
                guard index + 1 < flightNumbers.count,
                      let next = rangeOfFlightNumber(flightNumbers[index + 1], in: uppercase) else { return ns.length }
                return next.location
            }()

            let before = airportMatches.filter {
                NSMaxRange($0.range) <= flightRange.location &&
                $0.range.location >= max(previousFlightEnd, flightRange.location - 320)
            }
            let after = airportMatches.filter {
                $0.range.location >= NSMaxRange(flightRange) &&
                $0.range.location < min(nextFlightStart, NSMaxRange(flightRange) + 320)
            }

            var beforePair = routePair(from: Array(before.suffix(3)), expectedOrigin: expectedOrigin)
            var afterPair = routePair(from: Array(after.prefix(3)), expectedOrigin: expectedOrigin)
            if index < flightNumbers.count - 1 {
                if beforePair?.1 == destination.uppercased() { beforePair = nil }
                if afterPair?.1 == destination.uppercased() { afterPair = nil }
            }
            guard let pair = beforePair ?? afterPair else { return nil }

            route.append(pair.1)
            expectedOrigin = pair.1
            previousFlightEnd = NSMaxRange(flightRange)
        }

        guard route.first == origin.uppercased(), route.last == destination.uppercased(), route.count == flightNumbers.count + 1 else { return nil }
        return route
    }

    private static func routePair(
        from candidates: [(code: String, range: NSRange)],
        expectedOrigin: String
    ) -> (String, String)? {
        guard let originIndex = candidates.lastIndex(where: { $0.code == expectedOrigin }) else { return nil }
        guard originIndex + 1 < candidates.count else { return nil }
        for item in candidates[(originIndex + 1)...] where item.code != expectedOrigin {
            return (expectedOrigin, item.code)
        }
        return nil
    }

    private static func segmentTimes(
        from text: String,
        flightNumbers: [String],
        routeCodes: [String],
        fallback: [String],
        segmentCount: Int
    ) -> [String] {
        guard segmentCount > 1 else { return Array(fallback.prefix(2)) }
        guard routeCodes.count >= segmentCount + 1 else { return Array(fallback.suffix(segmentCount * 2)) }
        let uppercase = text.uppercased()
        let ns = uppercase as NSString
        var resolved: [String] = []
        var previousFlightEnd = 0

        for (index, number) in flightNumbers.enumerated() {
            guard let flightRange = rangeOfFlightNumber(number, in: uppercase) else {
                return Array(fallback.suffix(segmentCount * 2))
            }
            let nextFlightStart: Int = {
                guard index + 1 < flightNumbers.count,
                      let next = rangeOfFlightNumber(flightNumbers[index + 1], in: uppercase) else { return ns.length }
                return next.location
            }()

            let beforeStart = max(previousFlightEnd, flightRange.location - 320)
            let before = ns.substring(with: NSRange(location: beforeStart, length: flightRange.location - beforeStart))
            let afterStart = NSMaxRange(flightRange)
            let afterEnd = min(nextFlightStart, afterStart + 360)
            let after = afterEnd > afterStart
                ? ns.substring(with: NSRange(location: afterStart, length: afterEnd - afterStart))
                : ""

            let origin = routeCodes[index].uppercased()
            let destination = routeCodes[index + 1].uppercased()
            let beforePair = routeTimePair(in: before, origin: origin, destination: destination, preferSuffix: true)
            let afterPair = routeTimePair(in: after, origin: origin, destination: destination, preferSuffix: false)
            guard let pair = beforePair ?? afterPair else {
                return Array(fallback.suffix(segmentCount * 2))
            }
            resolved.append(contentsOf: pair)
            previousFlightEnd = NSMaxRange(flightRange)
        }
        return resolved.count >= segmentCount * 2
            ? Array(resolved.prefix(segmentCount * 2))
            : Array(fallback.suffix(segmentCount * 2))
    }

    private static func routeTimePair(
        in text: String,
        origin: String,
        destination: String,
        preferSuffix: Bool
    ) -> [String]? {
        let upper = text.uppercased()
        guard let originRange = upper.range(of: origin),
              let destinationRange = upper.range(of: destination, range: originRange.upperBound..<upper.endIndex),
              originRange.lowerBound < destinationRange.lowerBound else { return nil }
        let values = extractTimes(from: text)
        guard values.count >= 2 else { return nil }
        return preferSuffix ? Array(values.suffix(2)) : Array(values.prefix(2))
    }

    private static func rangeOfFlightNumber(_ number: String, in uppercaseText: String) -> NSRange? {
        let compact = number.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        guard compact.count >= 3 else { return nil }
        let code = String(compact.prefix(2)).uppercased()
        let digits = String(compact.dropFirst(2))
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: code) + #"[\s-]?"# + NSRegularExpression.escapedPattern(for: digits) + #"\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = uppercaseText as NSString
        return regex.firstMatch(in: uppercaseText, range: NSRange(location: 0, length: ns.length))?.range
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
            guard flightNumbers.indices.contains(index) else { return [] }
            let number = flightNumbers[index]
            guard let code = FlightReferenceCatalog.airlineCode(from: number), FlightReferenceCatalog.airline(code: code) != nil else { return [] }
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
                    // Segment duration is intentionally not synthesized from UTC
                    // offsets. Providers often show local times without enough date
                    // context. Keep it unknown unless the source explicitly says it.
                    durationMinutes: 0,
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
            .filter { !ignored.contains($0) && FlightReferenceCatalog.airport($0) != nil }
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

        return FlightReferenceCatalog.airline(code: providerCode(provider.id))?.name ?? provider.displayName
    }

    private static func inferredStops(from block: String) -> Int? {
        let lower = block.lowercased()
        if let count = firstCapture(pattern: #"([1-3])\s*(?:stop|stops|пересад(?:ка|ки|ок)?|to['’‘]?xtash)"#, in: lower),
           let value = Int(count) {
            return value
        }
        let directMarkers = ["nonstop", "non-stop", "0 stops", "0 stop", "direct flight", "прямой рейс", "без пересадок", "to‘g‘ridan-to‘g‘ri reys"]
        if directMarkers.contains(where: { lower.contains($0) }) { return 0 }
        return nil
    }

    private static func explicitDurationMinutes(from text: String) -> Int? {
        let patterns = [
            #"\b(\d{1,2})\s*h(?:r|rs|our|ours)?\s*(\d{1,2})?\s*m(?:in|ins|inute|inutes)?\b"#,
            #"\b(\d{1,2})\s*ч(?:\.|ас(?:а|ов)?)?\s*(\d{1,2})?\s*м(?:\.|ин(?:ут)?)?\b"#,
            #"\b(\d{1,2})\s*soat\s*(\d{1,2})?\s*daq(?:iqa)?\b"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges >= 2 else { continue }
            let hours = match.range(at: 1).location == NSNotFound ? 0 : Int(ns.substring(with: match.range(at: 1))) ?? 0
            let minutes = match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound ? Int(ns.substring(with: match.range(at: 2))) ?? 0 : 0
            let total = hours * 60 + minutes
            if total > 0 && total <= 72 * 60 { return total }
        }
        return nil
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

    private static func extractTimes(from text: String) -> [String] {
        let pattern = #"\b(?:(?:[01]?\d|2[0-3]):[0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*(?:AM|PM))\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        var output: [String] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard match.range.location != NSNotFound else { continue }
            let raw = ns.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = raw.uppercased()
            if upper.hasSuffix("AM") || upper.hasSuffix("PM") {
                let isPM = upper.hasSuffix("PM")
                let clock = upper.replacingOccurrences(of: "AM", with: "").replacingOccurrences(of: "PM", with: "").trimmingCharacters(in: .whitespaces)
                let parts = clock.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }
                var hour = parts[0] % 12
                if isPM { hour += 12 }
                output.append(String(format: "%02d:%02d", hour, parts[1]))
            } else {
                let parts = raw.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }
                output.append(String(format: "%02d:%02d", parts[0], parts[1]))
            }
        }
        return output
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
