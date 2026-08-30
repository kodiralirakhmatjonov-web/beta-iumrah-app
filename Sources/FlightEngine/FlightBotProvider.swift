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

    // Retained only for decoding old local checkpoints. Aggregators are not part
    // of the production provider registry and can never generate a visible flight.
    case googleFlights
    case skyscanner

    var id: String { rawValue }

    var isAggregator: Bool {
        self == .googleFlights || self == .skyscanner
    }
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

    var isOfficialCarrierSource: Bool { !id.isAggregator }

    func searchURL(for request: FlightBotSearchRequest) -> URL {
        // Production search intentionally opens the airline's own booking surface.
        // No Google Flights/Skyscanner provider is registered below.
        baseURL
    }
}

enum FlightBotProviderRegistry {
    static let uzbekistanAirportCodes: Set<String> = [
        "TAS", "SKD", "BHK", "UGC", "NMA", "FEG", "NCU", "TMJ", "KSQ", "AZN", "NAV"
    ]
    static let saudiAirportCodes: Set<String> = ["JED", "MED", "RUH", "DMM", "TIF"]

    /// Production sources are official airline booking surfaces only. Aggregators
    /// were removed because their DOM can expose provider names and fare-reference
    /// rows without the exact operating flight number, which is unacceptable for
    /// a booking product.
    static let providers: [FlightBotProvider] = [
        FlightBotProvider(
            id: .uzbekistanAirways,
            displayName: "Uzbekistan Airways",
            marketScope: .uzbekistanPriority,
            priority: 10,
            baseURL: URL(string: "https://booking.uzairways.com/")!,
            defaultFareScope: .perPassenger
        ),
        FlightBotProvider(
            id: .qanotSharq,
            displayName: "Qanot Sharq",
            marketScope: .uzbekistanPriority,
            priority: 20,
            baseURL: URL(string: "https://qanotsharq.com/en")!,
            defaultFareScope: .perPassenger
        ),
        FlightBotProvider(
            id: .centrumAir,
            displayName: "Centrum Air",
            marketScope: .uzbekistanPriority,
            priority: 30,
            baseURL: URL(string: "https://booking.centrum-air.com/ibe/C6/home/?language=en")!,
            defaultFareScope: .perPassenger
        ),
        FlightBotProvider(
            id: .airSamarkand,
            displayName: "Air Samarkand",
            marketScope: .uzbekistanPriority,
            priority: 40,
            baseURL: URL(string: "https://booking.airsamarkand.com/en/")!,
            defaultFareScope: .perPassenger
        ),
        FlightBotProvider(
            id: .flyKhiva,
            displayName: "Fly Khiva",
            marketScope: .uzbekistanPriority,
            priority: 50,
            baseURL: URL(string: "https://booking.flykhiva.uz/new/")!,
            defaultFareScope: .perPassenger
        ),
        FlightBotProvider(
            id: .silkAvia,
            displayName: "Silk Avia",
            marketScope: .uzbekistanPriority,
            priority: 60,
            baseURL: URL(string: "https://pss.silk-avia.com/ibe/search?lang=en")!,
            defaultFareScope: .perPassenger
        ),

        FlightBotProvider(id: .airArabia, displayName: "Air Arabia", marketScope: .regional, priority: 70, baseURL: URL(string: "https://www.airarabia.com/en")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .flydubai, displayName: "flydubai", marketScope: .regional, priority: 75, baseURL: URL(string: "https://www.flydubai.com/en/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .turkishAirlines, displayName: "Turkish Airlines", marketScope: .regional, priority: 80, baseURL: URL(string: "https://www.turkishairlines.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .jazeeraAirways, displayName: "Jazeera Airways", marketScope: .regional, priority: 85, baseURL: URL(string: "https://www.jazeeraairways.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .saudia, displayName: "Saudia", marketScope: .regional, priority: 90, baseURL: URL(string: "https://www.saudia.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .flynas, displayName: "flynas", marketScope: .regional, priority: 95, baseURL: URL(string: "https://www.flynas.com/en")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .airAstana, displayName: "Air Astana", marketScope: .regional, priority: 100, baseURL: URL(string: "https://airastana.com/")!, defaultFareScope: .perPassenger),
        FlightBotProvider(id: .flyArystan, displayName: "FlyArystan", marketScope: .regional, priority: 105, baseURL: URL(string: "https://flyarystan.com/")!, defaultFareScope: .perPassenger),
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
            ids = [.uzbekistanAirways, .qanotSharq, .centrumAir, .silkAvia, .airSamarkand, .flyKhiva]
        } else if fromUzbekistan || toUzbekistan {
            // Uzbek carriers get the first six slots for both directions. This is
            // what makes TAS/SKD/etc. inventory visible before regional connections.
            ids = [
                .uzbekistanAirways, .qanotSharq, .centrumAir, .airSamarkand, .flyKhiva, .silkAvia,
                .airArabia, .flydubai, .turkishAirlines, .jazeeraAirways,
                .saudia, .flynas, .airAstana, .flyArystan,
            ]
        } else if saudiRoute {
            ids = [
                .saudia, .flynas, .airArabia, .flydubai, .jazeeraAirways, .turkishAirlines,
                .airAstana, .flyArystan, .uzbekistanAirways, .qanotSharq,
            ]
        } else {
            ids = [
                .turkishAirlines, .airArabia, .flydubai, .jazeeraAirways,
                .airAstana, .flyArystan, .saudia, .flynas,
                .uzbekistanAirways, .qanotSharq,
            ]
        }

        return ids.compactMap { byID[$0] }.filter(\.isOfficialCarrierSource)
    }
}
