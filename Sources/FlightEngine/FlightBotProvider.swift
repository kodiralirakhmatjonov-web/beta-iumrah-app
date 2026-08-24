import Foundation

enum FlightBotProviderID: String, CaseIterable, Codable, Hashable, Identifiable {
    case uzbekistanAirways
    case qanotSharq
    case centrumAir
    case silkAvia
    case airSamarkand
    case flyKhiva
    case googleFlights
    case skyscanner

    var id: String { rawValue }
}

struct FlightBotProvider: Identifiable, Hashable {
    enum MarketScope: String, Hashable {
        case uzbekistanPriority
        case global
    }

    let id: FlightBotProviderID
    let displayName: String
    let marketScope: MarketScope
    let priority: Int
    let baseURL: URL

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
    static let providers: [FlightBotProvider] = [
        FlightBotProvider(
            id: .uzbekistanAirways,
            displayName: "Uzbekistan Airways",
            marketScope: .uzbekistanPriority,
            priority: 10,
            baseURL: URL(string: "https://booking.uzairways.com/en/index.html?optdisable=1")!
        ),
        FlightBotProvider(
            id: .qanotSharq,
            displayName: "Qanot Sharq",
            marketScope: .uzbekistanPriority,
            priority: 20,
            baseURL: URL(string: "https://booking.qanotsharq.com/websky_grs/")!
        ),
        FlightBotProvider(
            id: .centrumAir,
            displayName: "Centrum Air",
            marketScope: .uzbekistanPriority,
            priority: 30,
            baseURL: URL(string: "https://booking.centrum-air.com/ibe/C6/home/?language=en")!
        ),
        FlightBotProvider(
            id: .silkAvia,
            displayName: "Silk Avia",
            marketScope: .uzbekistanPriority,
            priority: 40,
            baseURL: URL(string: "https://pss.silk-avia.com/ibe/search?lang=en")!
        ),
        FlightBotProvider(
            id: .airSamarkand,
            displayName: "Air Samarkand",
            marketScope: .uzbekistanPriority,
            priority: 50,
            baseURL: URL(string: "https://booking.airsamarkand.com/en/")!
        ),
        FlightBotProvider(
            id: .flyKhiva,
            displayName: "Fly Khiva",
            marketScope: .uzbekistanPriority,
            priority: 60,
            baseURL: URL(string: "https://booking.flykhiva.uz/en/")!
        ),
        FlightBotProvider(
            id: .googleFlights,
            displayName: "Google Flights",
            marketScope: .global,
            priority: 70,
            baseURL: URL(string: "https://www.google.com/travel/flights")!
        ),
        FlightBotProvider(
            id: .skyscanner,
            displayName: "Skyscanner",
            marketScope: .global,
            priority: 80,
            baseURL: URL(string: "https://www.skyscanner.com/transport/flights")!
        )
    ]

    static func ordered(for origin: String) -> [FlightBotProvider] {
        let upper = origin.uppercased()
        let uzbekistanAirports: Set<String> = ["TAS", "SKD", "BHK", "UGC", "NMA", "FEG", "NCU", "TMJ", "KSQ", "AZN"]
        if uzbekistanAirports.contains(upper) {
            return providers.sorted { $0.priority < $1.priority }
        }
        return providers.sorted {
            if $0.marketScope != $1.marketScope {
                return $0.marketScope == .global
            }
            return $0.priority < $1.priority
        }
    }
}
