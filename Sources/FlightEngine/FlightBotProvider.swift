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

    enum ExecutionProfile: String, Hashable {
        /// Uzbekistan Airways' own booking form. Server may submit the first-party
        /// route form; iPhone keeps a dedicated WebKit adapter as a fallback.
        case uzbekistanBooking
        /// Qanot Sharq exposes a stable first-party WebSky deep-search URL, but
        /// the production result surface requires JavaScript. It therefore runs
        /// in WKWebView rather than being misrepresented as a server HTTP bot.
        case qanotWebSky
        /// Centrum's IBE currently presents interactive anti-bot verification,
        /// therefore production discovery is device-assisted only.
        case centrumIBEDevice
        /// Air Samarkand's booking frontend is sessionful; production discovery is
        /// kept on the persistent device WebKit session until a stable HTTP contract
        /// is verified independently.
        case airSamarkandSessionDevice
    }

    let id: FlightBotProviderID
    let displayName: String
    let marketScope: MarketScope
    let priority: Int
    let baseURL: URL
    let defaultFareScope: FlightFareScope
    let airlineCodes: Set<String>
    let officialHosts: Set<String>
    let executionProfile: ExecutionProfile
    let supportsServerSearch: Bool
    let supportsDeviceSearch: Bool
    let deviceTimeoutSeconds: Double

    var isOfficialCarrierSource: Bool { !id.isAggregator }

    var usesDirectSearchURL: Bool {
        executionProfile == .qanotWebSky
    }

    func acceptsSourceURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return officialHosts.contains { trusted in
            host == trusted || host.hasSuffix(".\(trusted)")
        }
    }

    func acceptsPrimaryFlightNumber(_ value: String) -> Bool {
        guard let normalized = FlightReferenceCatalog.normalizedVerifiedFlightNumber(value),
              let code = FlightReferenceCatalog.airlineCode(from: normalized) else { return false }
        return airlineCodes.contains(code.uppercased())
    }

    func searchURL(for request: FlightBotSearchRequest) -> URL {
        switch executionProfile {
        case .qanotWebSky:
            var components = URLComponents(string: "https://booking.qanotsharq.com/websky_grs/")!
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "dd.MM.yyyy"
            components.queryItems = [
                URLQueryItem(name: "origin-city-code[0]", value: request.origin.uppercased()),
                URLQueryItem(name: "destination-city-code[0]", value: request.destination.uppercased()),
                URLQueryItem(name: "date[0]", value: formatter.string(from: request.date)),
                URLQueryItem(name: "segmentsCount", value: "1"),
                URLQueryItem(name: "adultsCount", value: String(max(1, request.adults))),
                URLQueryItem(name: "childrenCount", value: String(max(0, request.children))),
                URLQueryItem(name: "infantsWithoutSeatCount", value: String(max(0, request.infants))),
                URLQueryItem(name: "infantsWithSeatCount", value: "0"),
                URLQueryItem(name: "searchGroupId", value: "standard"),
                URLQueryItem(name: "lang", value: "en")
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

    /// Production registry intentionally contains only the first four carriers.
    /// Future provider IDs remain Codable for old checkpoints, but they are not
    /// searched until each booking engine has its own validated adapter.
    static let providers: [FlightBotProvider] = [
        FlightBotProvider(
            id: .uzbekistanAirways,
            displayName: "Uzbekistan Airways",
            marketScope: .uzbekistanPriority,
            priority: 10,
            baseURL: URL(string: "https://booking.uzairways.com/")!,
            defaultFareScope: .perPassenger,
            airlineCodes: ["HY"],
            officialHosts: ["booking.uzairways.com"],
            executionProfile: .uzbekistanBooking,
            supportsServerSearch: true,
            supportsDeviceSearch: true,
            deviceTimeoutSeconds: 16
        ),
        FlightBotProvider(
            id: .qanotSharq,
            displayName: "Qanot Sharq",
            marketScope: .uzbekistanPriority,
            priority: 20,
            baseURL: URL(string: "https://booking.qanotsharq.com/websky_grs/")!,
            defaultFareScope: .perPassenger,
            airlineCodes: ["HH"],
            officialHosts: ["booking.qanotsharq.com"],
            executionProfile: .qanotWebSky,
            supportsServerSearch: false,
            supportsDeviceSearch: true,
            deviceTimeoutSeconds: 20
        ),
        FlightBotProvider(
            id: .centrumAir,
            displayName: "Centrum Air",
            marketScope: .uzbekistanPriority,
            priority: 30,
            baseURL: URL(string: "https://booking.centrum-air.com/ibe/C6/home/?language=en")!,
            defaultFareScope: .perPassenger,
            airlineCodes: ["C6"],
            officialHosts: ["booking.centrum-air.com"],
            executionProfile: .centrumIBEDevice,
            supportsServerSearch: false,
            supportsDeviceSearch: true,
            deviceTimeoutSeconds: 24
        ),
        FlightBotProvider(
            id: .airSamarkand,
            displayName: "Air Samarkand",
            marketScope: .uzbekistanPriority,
            priority: 40,
            baseURL: URL(string: "https://booking.airsamarkand.com/en/?tsi_frontoffice_cmd=index")!,
            defaultFareScope: .perPassenger,
            airlineCodes: ["9S"],
            officialHosts: ["booking.airsamarkand.com"],
            executionProfile: .airSamarkandSessionDevice,
            supportsServerSearch: false,
            supportsDeviceSearch: true,
            deviceTimeoutSeconds: 20
        )
    ]

    static func ordered(for origin: String, destination: String? = nil) -> [FlightBotProvider] {
        // The first production milestone is deliberately narrow: these four
        // provider-specific adapters are attempted in stable priority order.
        providers.sorted { $0.priority < $1.priority }
    }

    static func serverProviders(for origin: String, destination: String? = nil) -> [FlightBotProvider] {
        ordered(for: origin, destination: destination).filter(\.supportsServerSearch)
    }

    static func deviceProviders(for origin: String, destination: String? = nil) -> [FlightBotProvider] {
        ordered(for: origin, destination: destination).filter(\.supportsDeviceSearch)
    }
}
