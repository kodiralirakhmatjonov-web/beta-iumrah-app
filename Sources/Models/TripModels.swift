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

struct TripDraft: Codable, Hashable {
    var origin: String = "TAS"
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

    var canContinue: Bool {
        !origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        adults > 0 &&
        rooms > 0 &&
        returnDate > departureDate
    }
}
