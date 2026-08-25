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
    case plusMinusOne
    case plusMinusTwo
    case weekend

    var id: String { rawValue }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .exact: return L10n.text("flex_exact", language)
        case .plusMinusOne: return L10n.text("flex_pm1", language)
        case .plusMinusTwo: return L10n.text("flex_pm2", language)
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

    var originCode: String {
        (originAirport?.iata ?? origin).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var outboundDestinationCode: String {
        guard scope == .makkahAndMadinah else { return "JED" }
        return arrivalAirport.rawValue
    }

    var returnOriginCode: String {
        guard scope == .makkahAndMadinah else { return "JED" }
        return arrivalAirport == .madinah ? "JED" : "MED"
    }

    var canContinue: Bool {
        originCode.count == 3 &&
        adults > 0 &&
        rooms > 0 &&
        returnDate > departureDate
    }
}
