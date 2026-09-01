import Foundation

enum PackageTier: String, CaseIterable, Codable, Identifiable, Hashable {
    case economy
    case standard
    case comfort
    case luxury

    var id: String { rawValue }

    func title(_ language: AppSettingsStore.Language) -> String {
        L10n.text("tier_\(rawValue)", language)
    }

    func subtitle(_ language: AppSettingsStore.Language) -> String {
        L10n.text("tier_\(rawValue)_subtitle", language)
    }
}

enum DateFlexibility: String, CaseIterable, Codable, Identifiable, Hashable {
    case exact
    /// Retained only so previously persisted drafts continue to decode.
    case plusMinusOne
    case plusMinusTwo
    case weekend

    /// The current product has one flexible flight-discovery mode: search a full
    /// seven-day window around the selected date. The old ±1 raw value remains
    /// decodable and is normalized into the same weekly mode.
    static var allCases: [DateFlexibility] { [.exact, .plusMinusTwo, .weekend] }

    var id: String { rawValue }

    var isFlexibleDayRange: Bool {
        self == .plusMinusOne || self == .plusMinusTwo
    }

    var isWeeklyDiscovery: Bool { isFlexibleDayRange }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .exact: return L10n.text("flex_exact", language)
        case .plusMinusOne, .plusMinusTwo: return L10n.text("flex_pm2", language)
        case .weekend: return L10n.text("flex_weekend", language)
        }
    }
}

enum JourneyScope: String, CaseIterable, Codable, Identifiable, Hashable {
    case makkahOnly
    case makkahAndMadinah

    var id: String { rawValue }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .makkahOnly: return L10n.text("scope_makkah", language)
        case .makkahAndMadinah: return L10n.text("scope_both", language)
        }
    }
}

enum SaudiArrivalAirport: String, CaseIterable, Codable, Identifiable, Hashable {
    case jeddah = "JED"
    case madinah = "MED"

    var id: String { rawValue }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .jeddah: return L10n.text("airport_jeddah_full", language)
        case .madinah: return L10n.text("airport_madinah", language)
        }
    }

    func shortTitle(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .jeddah: return L10n.text("airport_jeddah", language)
        case .madinah: return L10n.text("airport_madinah", language)
        }
    }
}

struct TripDraft: Codable, Hashable {
    var origin: String = "TAS"
    var originAirport: Airport? = nil
    var arrivalAirport: SaudiArrivalAirport = .jeddah
    var departureDate: Date = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
    var returnDate: Date = Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date()
    var flexibility: DateFlexibility = .exact
    var adults: Int = 2
    var children: Int = 0
    var infants: Int = 0
    var rooms: Int = 1
    var hotelStars: Int = 4
    var packageTier: PackageTier = .standard
    var scope: JourneyScope = .makkahAndMadinah

    var travelerCount: Int { adults + children + infants }
    var isWeekendUmrah: Bool { flexibility == .weekend }

    var originCode: String {
        (originAirport?.iata ?? origin).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var outboundDestinationCode: String {
        if isWeekendUmrah { return "JED" }
        guard scope == .makkahAndMadinah else { return "JED" }
        return arrivalAirport.rawValue
    }

    var returnOriginCode: String {
        if isWeekendUmrah { return "JED" }
        guard scope == .makkahAndMadinah else { return "JED" }
        return arrivalAirport == .madinah ? "JED" : "MED"
    }

    mutating func selectFlexibility(_ value: DateFlexibility, calendar: Calendar = .current) {
        flexibility = value == .plusMinusOne ? .plusMinusTwo : value
        if flexibility == .weekend {
            applyWeekendWindow(around: departureDate, calendar: calendar)
        }
    }

    /// Weekend Umrah is intentionally a separate product route: origin → JED and
    /// JED → origin, without a Madinah flight leg. The travel window is Friday to
    /// Monday so Saturday/Sunday remain fully available for Umrah.
    mutating func applyWeekendWindow(around referenceDate: Date, calendar: Calendar = .current) {
        scope = .makkahOnly
        arrivalAirport = .jeddah

        let today = calendar.startOfDay(for: Date())
        let reference = max(calendar.startOfDay(for: referenceDate), today)
        let weekday = calendar.component(.weekday, from: reference) // Sunday = 1, Friday = 6
        let daysForwardToFriday = (6 - weekday + 7) % 7
        var friday = calendar.date(byAdding: .day, value: daysForwardToFriday, to: reference) ?? reference

        // If the user is already inside a future Friday–Sunday weekend, preserve
        // that weekend instead of jumping a full week ahead.
        if weekday == 7, let previousFriday = calendar.date(byAdding: .day, value: -1, to: reference), previousFriday >= today {
            friday = previousFriday
        } else if weekday == 1, let previousFriday = calendar.date(byAdding: .day, value: -2, to: reference), previousFriday >= today {
            friday = previousFriday
        }

        departureDate = friday
        returnDate = calendar.date(byAdding: .day, value: 3, to: friday) ?? friday.addingTimeInterval(3 * 86_400)
    }

    var canContinue: Bool {
        originCode.count == 3 &&
        adults > 0 &&
        rooms > 0 &&
        returnDate > departureDate
    }
}
