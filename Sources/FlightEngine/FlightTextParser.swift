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
        guard let fare = parseFare(block) else { return nil }
        let times = matches(pattern: #"\b(?:[01]?\d|2[0-3]):[0-5]\d\b"#, in: block)
        guard let departureTime = times.first else { return nil }
        let arrivalTime = times.count > 1 ? times[1] : departureTime

        let flightNumber = matches(pattern: #"\b[A-Z0-9]{2,3}[\s-]?\d{1,4}\b"#, in: block.uppercased()).first ?? providerCode(provider.id)
        let airline = inferredAirline(from: block, provider: provider)
        let stops = inferredStops(from: block)

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: request.date)
        guard let departure = combine(day: day, hhmm: departureTime, calendar: calendar) else { return nil }
        var arrival = combine(day: day, hhmm: arrivalTime, calendar: calendar) ?? departure
        if arrival < departure { arrival = calendar.date(byAdding: .day, value: 1, to: arrival) ?? arrival }
        let duration = max(0, Int(arrival.timeIntervalSince(departure) / 60))

        return LiveFlightCandidate(
            id: UUID().uuidString,
            providerID: provider.id,
            providerName: provider.displayName,
            direction: request.direction,
            airline: airline,
            flightNumber: flightNumber,
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
            rawTextFingerprint: stableFingerprint(block)
        )
    }

    private static func parseFare(_ text: String) -> (amount: Decimal, currency: String, scope: FlightFareScope)? {
        let patterns: [(String, String)] = [
            (#"\$\s*([0-9][0-9\s,.]*)"#, "USD"),
            (#"USD\s*([0-9][0-9\s,.]*)"#, "USD"),
            (#"([0-9][0-9\s,.]*)\s*USD"#, "USD"),
            (#"UZS\s*([0-9][0-9\s,.]*)"#, "UZS"),
            (#"([0-9][0-9\s,.]*)\s*UZS"#, "UZS"),
            (#"€\s*([0-9][0-9\s,.]*)"#, "EUR"),
            (#"EUR\s*([0-9][0-9\s,.]*)"#, "EUR"),
            (#"₽\s*([0-9][0-9\s,.]*)"#, "RUB"),
            (#"RUB\s*([0-9][0-9\s,.]*)"#, "RUB"),
            (#"SAR\s*([0-9][0-9\s,.]*)"#, "SAR")
        ]

        for (pattern, currency) in patterns {
            guard let capture = firstCapture(pattern: pattern, in: text) else { continue }
            let normalized = capture.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: "")
            guard let decimal = Decimal(string: normalized), decimal > 0 else { continue }
            let lower = text.lowercased()
            let scope: FlightFareScope = lower.contains("total") || lower.contains("итого") || lower.contains("за всех") ? .totalParty : .unknown
            return (decimal, currency, scope)
        }
        return nil
    }

    private static func inferredAirline(from block: String, provider: FlightBotProvider) -> String {
        if provider.marketScope == .uzbekistanPriority { return provider.displayName }
        let known = [
            "Uzbekistan Airways", "Qanot Sharq", "Centrum Air", "Silk Avia", "Air Samarkand", "Fly Khiva",
            "Flynas", "Saudia", "Turkish Airlines", "Qatar Airways", "Emirates", "Air Arabia", "Jazeera Airways",
            "Wizz Air", "Azerbaijan Airlines", "Pegasus", "flydubai"
        ]
        return known.first(where: { block.localizedCaseInsensitiveContains($0) }) ?? provider.displayName
    }

    private static func inferredStops(from block: String) -> Int {
        let lower = block.lowercased()
        if lower.contains("nonstop") || lower.contains("non-stop") || lower.contains("direct") || lower.contains("прям") { return 0 }
        if let count = firstCapture(pattern: #"([1-9])\s*(?:stop|stops|пересад)"#, in: lower), let value = Int(count) { return value }
        return 1
    }

    private static func providerCode(_ id: FlightBotProviderID) -> String {
        switch id {
        case .uzbekistanAirways: return "HY"
        case .qanotSharq: return "HH"
        case .centrumAir: return "C6"
        case .silkAvia: return "US"
        case .airSamarkand: return "9S"
        case .flyKhiva: return "2U"
        case .googleFlights: return "GF"
        case .skyscanner: return "SKY"
        }
    }

    private static func combine(day: Date, hhmm: String, calendar: Calendar) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.range.location != NSNotFound else { return nil }
            return ns.substring(with: match.range)
        }
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
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
