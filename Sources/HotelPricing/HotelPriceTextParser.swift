import Foundation

enum HotelPriceTextParser {
    struct ParsedPrice: Equatable {
        let amount: Decimal
        let currency: String
        let unit: HotelPriceUnit
    }

    /// Parses only a price that has an explicit stay/total or per-night meaning.
    /// Generic money elsewhere in the page is deliberately ignored: taxes, loyalty
    /// credits and crossed-out prices must never become the package hotel cost.
    static func parse(text: String, priceText: String, metaText: String) -> ParsedPrice? {
        let bodyLower = text.lowercased()
        let preferred = "\(metaText) \(priceText)"
        let preferredLower = preferred.lowercased()
        let promotionalMarkers = ["starting at", "prices from", "price from", "rates from", "dan boshlab"]
        let currencyFrom = bodyLower.range(
            of: #"\bfrom\s+(?:US\$|USD|[$€£]|EUR|SAR|AED|GBP)"#,
            options: .regularExpression
        ) != nil
        let russianFrom = bodyLower.range(
            of: #"\bот\s+(?:US\$|USD|[$€£]|EUR|SAR|AED|GBP|[0-9])"#,
            options: .regularExpression
        ) != nil
        guard !promotionalMarkers.contains(where: { bodyLower.contains($0) }),
              !currencyFrom,
              !russianFrom else { return nil }

        // Strongest signal: an explicit total/stay label adjacent to the amount.
        if let total = moneyNearStayContext(in: preferred) ?? moneyNearStayContext(in: text) {
            return ParsedPrice(amount: total.amount, currency: total.currency, unit: .totalStay)
        }

        // We only infer a unit from the compact provider price/meta widget. A random
        // "night" word elsewhere in the hotel page cannot change the unit anymore.
        let priceValues = moneyValues(in: priceText)
        let metaValues = moneyValues(in: metaText)
        let values = !priceValues.isEmpty ? priceValues : metaValues
        guard !values.isEmpty else { return nil }

        // Booking commonly renders a crossed-out old price plus the active discounted
        // price in the same price widget. The lower value is the current payable rate;
        // this rule is intentionally limited to that compact price widget.
        let value = priceValues.min(by: { $0.amount < $1.amount }) ?? values.last!
        if containsPerNightContext(preferredLower) {
            return ParsedPrice(amount: value.amount, currency: value.currency, unit: .perRoomNight)
        }
        if containsStayContext(preferredLower) {
            return ParsedPrice(amount: value.amount, currency: value.currency, unit: .totalStay)
        }
        return nil
    }

    private static func containsStayContext(_ lower: String) -> Bool {
        lower.range(
            of: #"(?:total|price for|stay|for\s+\d+\s+nights?|\d+\s+nights?)"#,
            options: .regularExpression
        ) != nil
    }

    private static func containsPerNightContext(_ lower: String) -> Bool {
        lower.contains("per night") ||
        lower.contains("/ night") ||
        lower.contains("nightly") ||
        lower.contains("each night")
    }

    static func normalizedDecimal(_ raw: String) -> Decimal? {
        var value = raw
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.range(of: #"^[0-9][0-9.,]*$"#, options: .regularExpression) != nil else { return nil }

        let comma = value.lastIndex(of: ",")
        let dot = value.lastIndex(of: ".")
        let decimalIndex: String.Index? = {
            let candidate: String.Index?
            switch (comma, dot) {
            case let (c?, d?): candidate = c > d ? c : d
            case let (c?, nil): candidate = c
            case let (nil, d?): candidate = d
            default: candidate = nil
            }
            guard let candidate else { return nil }
            let trailing = value.distance(from: value.index(after: candidate), to: value.endIndex)
            return (1...2).contains(trailing) ? candidate : nil
        }()

        if let decimalIndex {
            let whole = value[..<decimalIndex].filter(\.isNumber)
            let fraction = value[value.index(after: decimalIndex)...].filter(\.isNumber)
            value = "\(String(whole)).\(String(fraction))"
        } else {
            value = String(value.filter(\.isNumber))
        }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func moneyNearStayContext(in text: String) -> (amount: Decimal, currency: String)? {
        let patterns = [
            #"(?:total(?:\s+price)?|price for|for\s+\d+\s+nights?|\d+\s+nights?)[^\n|]{0,120}?(US\$|USD|\$|EUR|€|SAR|AED|GBP|£)\s*([0-9][0-9\s,.]*)"#,
            #"(US\$|USD|\$|EUR|€|SAR|AED|GBP|£)\s*([0-9][0-9\s,.]*)[^\n|]{0,80}?(?:total(?:\s+price)?|for\s+\d+\s+nights?|\d+\s+nights?)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = text as NSString
            guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
                  match.numberOfRanges >= 3 else { continue }
            let symbol = ns.substring(with: match.range(at: 1))
            let raw = ns.substring(with: match.range(at: 2))
            if let amount = normalizedDecimal(raw), amount > 0 {
                return (amount, currency(symbol))
            }
        }
        return nil
    }

    private static func moneyValues(in text: String) -> [(amount: Decimal, currency: String)] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(US\$|USD|\$|EUR|€|SAR|AED|GBP|£)\s*([0-9][0-9\s,.]*)"#,
            options: [.caseInsensitive]
        ) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let amount = normalizedDecimal(ns.substring(with: match.range(at: 2))),
                  amount > 0 else { return nil }
            return (amount, currency(ns.substring(with: match.range(at: 1))))
        }
    }

    private static func currency(_ symbol: String) -> String {
        switch symbol.uppercased() {
        case "EUR", "€": return "EUR"
        case "SAR": return "SAR"
        case "AED": return "AED"
        case "GBP", "£": return "GBP"
        default: return "USD"
        }
    }
}
