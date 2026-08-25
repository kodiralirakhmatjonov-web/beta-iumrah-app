import Foundation

enum PackageTier: String, CaseIterable, Codable, Identifiable, Hashable {
    case economy
    case standard
    case comfort
    case luxury

    var id: String { rawValue }

    var title: String {
        switch self {
        case .economy: return "Economy"
        case .standard: return "Standard"
        case .comfort: return "Comfort"
        case .luxury: return "Luxury"
        }
    }

    var subtitle: String {
        switch self {
        case .economy: return "Главное для самостоятельной Умры"
        case .standard: return "Баланс стоимости и комфорта"
        case .comfort: return "Больше удобства в поездке"
        case .luxury: return "Премиальный формат поездки"
        }
    }
}

enum DateFlexibility: String, CaseIterable, Codable, Identifiable, Hashable {
    case exact
    case plusMinusOne
    case plusMinusTwo
    case weekend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exact: return "Точно"
        case .plusMinusOne: return "±1 день"
        case .plusMinusTwo: return "±2 дня"
        case .weekend: return "Выходные"
        }
    }
}

enum JourneyScope: String, CaseIterable, Codable, Identifiable, Hashable {
    case makkahOnly
    case makkahAndMadinah

    var id: String { rawValue }

    var title: String {
        switch self {
        case .makkahOnly: return "Только Мекка"
        case .makkahAndMadinah: return "Мекка + Медина"
        }
    }
}


enum SaudiArrivalAirport: String, CaseIterable, Codable, Identifiable, Hashable {
    case jeddah = "JED"
    case madinah = "MED"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jeddah: return "Джидда · для Мекки"
        case .madinah: return "Медина"
        }
    }

    var shortTitle: String {
        switch self {
        case .jeddah: return "Джидда"
        case .madinah: return "Медина"
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
