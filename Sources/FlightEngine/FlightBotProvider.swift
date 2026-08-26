import Foundation

enum FlightBotProviderID: String, CaseIterable, Codable, Hashable, Identifiable {
    case uzbekistanAirways
    case qanotSharq
    case centrumAir
    case silkAvia
    case airSamarkand
    case flyKhiva
    case flynas
    case saudia
    case turkishAirlines
    case airArabia
    case jazeeraAirways
    case flydubai
    case airAstana
    case flyArystan
    case googleFlights
    case skyscanner

    var id: String { rawValue }
}

struct FlightBotProvider: Identifiable, Hashable {
    enum MarketScope: String, Hashable {
        case uzbekistanPriority
        case regional
        case global
    }

    let id: FlightBotProviderID
    let displayName: String
    let marketScope: MarketScope
    let priority: Int
    let baseURL: URL
    let defaultFareScope: FlightFareScope

    func searchURL(for request: FlightBotSearchRequest) -> URL {
        switch id {
        case .googleFlights:
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let date = formatter.string(from: request.date)
            let query = "Flights from \(request.origin) to \(request.destination) on \(date)"
            var components = URLComponents(string: "https://www.google.com/travel/flights")!
            components.queryItems = [
                URLQueryItem(name: "hl", value: "en"),
                URLQueryItem(name: "curr", value: "USD"),
                URLQueryItem(name: "q", value: query)
            ]
            return components.url ?? baseURL

        case .skyscanner:
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyMMdd"
            let date = formatter.string(from: request.date)
            let route = "https://www.skyscanner.com/transport/flights/\(request.origin.lowercased())/\(request.destination.lowercased())/\(date)/"
            var components = URLComponents(string: route)!
            components.queryItems = [
                URLQueryItem(name: "adultsv2", value: String(max(1, request.adults))),
                URLQueryItem(name: "childrenv2", value: String(request.children)),
                URLQueryItem(name: "infants", value: String(request.infants)),
                URLQueryItem(name: "cabinclass", value: request.cabin),
                URLQueryItem(name: "currency", value: "USD")
            ]
            return components.url ?? baseURL

        default:
            return baseURL
        }
    }
}

enum FlightBotProviderRegistry {
    static let uzbekistanAirportCodes: Set<String> = [
        "TAS", "SKD", "BHK", "UGC", "NMA", "FEG", "NCU", "TMJ", "KSQ", "AZN", "NAV"
    ]
    static let saudiAirportCodes: Set<String> = ["JED", "MED", "RUH", "DMM", "TIF"]

    static let providers: [FlightBotProvider] = [
        FlightBotProvider(id: .uzbekistanAirways, displayName: "Uzbekistan Airways", marketScope: .uzbekistanPriority, priority: 10, baseURL: URL(string: "https://booking.uzairways.com/en/index.html?optdisable=1")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .qanotSharq, displayName: "Qanot Sharq", marketScope: .uzbekistanPriority, priority: 20, baseURL: URL(string: "https://booking.qanotsharq.com/websky_grs/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .centrumAir, displayName: "Centrum Air", marketScope: .uzbekistanPriority, priority: 30, baseURL: URL(string: "https://booking.centrum-air.com/ibe/C6/home/?language=en")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .silkAvia, displayName: "Silk Avia", marketScope: .uzbekistanPriority, priority: 40, baseURL: URL(string: "https://pss.silk-avia.com/ibe/search?lang=en")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .airSamarkand, displayName: "Air Samarkand", marketScope: .uzbekistanPriority, priority: 50, baseURL: URL(string: "https://booking.airsamarkand.com/en/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .flyKhiva, displayName: "Fly Khiva", marketScope: .uzbekistanPriority, priority: 60, baseURL: URL(string: "https://www.flykhiva.uz/en")!, defaultFareScope: .perPassenger),

        // Regional sources are especially useful for Uzbekistan → Saudi Arabia
        // itineraries and one-stop alternatives. They remain below direct Uzbek
        // carriers so local inventory is searched first.
        FlightBotProvider(id: .flynas, displayName: "flynas", marketScope: .regional, priority: 70, baseURL: URL(string: "https://www.flynas.com/en")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .saudia, displayName: "Saudia", marketScope: .regional, priority: 75, baseURL: URL(string: "https://www.saudia.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .turkishAirlines, displayName: "Turkish Airlines", marketScope: .regional, priority: 80, baseURL: URL(string: "https://www.turkishairlines.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .airArabia, displayName: "Air Arabia", marketScope: .regional, priority: 85, baseURL: URL(string: "https://www.airarabia.com/en")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .jazeeraAirways, displayName: "Jazeera Airways", marketScope: .regional, priority: 90, baseURL: URL(string: "https://www.jazeeraairways.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .flydubai, displayName: "flydubai", marketScope: .regional, priority: 95, baseURL: URL(string: "https://www.flydubai.com/en/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .airAstana, displayName: "Air Astana", marketScope: .regional, priority: 100, baseURL: URL(string: "https://airastana.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .flyArystan, displayName: "FlyArystan", marketScope: .regional, priority: 105, baseURL: URL(string: "https://flyarystan.com/")!, defaultFareScope: .perPassenger),

        FlightBotProvider(id: .googleFlights, displayName: "Google Flights", marketScope: .global, priority: 120, baseURL: URL(string: "https://www.google.com/travel/flights")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .skyscanner, displayName: "Skyscanner", marketScope: .global, priority: 130, baseURL: URL(string: "https://www.skyscanner.com/transport/flights")!, defaultFareScope: .perPassenger)
    ]

    static func ordered(for origin: String, destination: String? = nil) -> [FlightBotProvider] {
        let from = origin.uppercased()
        let to = destination?.uppercased()
        let fromUzbekistan = uzbekistanAirportCodes.contains(from)
        let toUzbekistan = to.map(uzbekistanAirportCodes.contains) ?? false
        let domesticUzbekistan = fromUzbekistan && toUzbekistan
        let saudiRoute = saudiAirportCodes.contains(from) || (to.map(saudiAirportCodes.contains) ?? false)
        let byID = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })

        let ids: [FlightBotProviderID]
        if domesticUzbekistan {
            // Search the local market first, but put one broad discovery source in
            // the first batch so a broken airline booking form cannot stall the UI.
            ids = [
                .uzbekistanAirways, .qanotSharq, .centrumAir, .googleFlights,
                .silkAvia, .airSamarkand, .flyKhiva, .skyscanner,
            ]
        } else if fromUzbekistan || toUzbekistan {
            ids = [
                .uzbekistanAirways, .qanotSharq, .centrumAir, .googleFlights,
                .airSamarkand, .silkAvia, .flyKhiva, .skyscanner,
                .flynas, .turkishAirlines, .airArabia, .flydubai,
                .jazeeraAirways, .saudia, .airAstana, .flyArystan,
            ]
        } else if saudiRoute {
            ids = [
                .flynas, .saudia, .turkishAirlines, .googleFlights,
                .airArabia, .jazeeraAirways, .flydubai, .skyscanner,
                .airAstana, .flyArystan, .uzbekistanAirways,
            ]
        } else {
            ids = [
                .turkishAirlines, .airArabia, .flydubai, .googleFlights,
                .jazeeraAirways, .airAstana, .flyArystan, .skyscanner,
                .uzbekistanAirways,
            ]
        }

        return ids.compactMap { byID[$0] }
    }
}
