import Foundation

enum AppConfig {
    enum FlightEngineMode: Equatable {
        case officialWebBots
    }

    static let appName = "iumrah Beta"
    static let apiBaseURL = URL(string: "https://iumrah.app")!

    /// Generator V2 production mode: real airline provider bots with hybrid
    /// server + device execution. Final package pricing is calculated locally
    /// in the app by LocalPackagePricingEngine; the server only returns components.
    static let flightEngineMode: FlightEngineMode = .officialWebBots
    // One verified option is enough to keep the journey moving; the engine still
    // searches toward four-to-six options. A weak provider must never zero-out an
    // otherwise usable search result.
    static let flightBotMinimumOptions = 1
    static let flightBotTargetOptions = 4
    static let flightBotPreferredOptions = 6
    static let flightBotProviderBatchSize = 2
    static let flightBotProviderTimeoutSeconds: Double = 12
    static let flightBotSearchHardTimeoutSeconds: Double = 165
    static let flightSearchScreenHardTimeoutSeconds: Double = 132

    static let hotelPriceProviderTimeoutSeconds: Double = 17
    static let hotelPriceSearchHardTimeoutSeconds: Double = 46

    static let packageHealthPath = "/api/package/health"
    static let packageQuotePath = "/api/package/quote"
    static let packageFlightOptionsQuotePath = "/api/package/flight-options/quote"
    static let packageFlightProviderSearchPath = "/api/package/flights/provider-search"
    static let packageHotelComponentPricePath = "/api/package/hotel-component-price"
    static let packageBookingPath = "/api/bookings"
    static let serverFlightProviderTimeoutSeconds: Double = 14
    static let usesServerPrimaryHotelResolver = true

    /// Primary hotel assignments are resolved server-side from the package tier,
    /// hotel stars and existing iumrah Hotels D1 catalog.
    static let usesLocalPrimaryHotelFallback = true

    static var isStrictRealFlightTest: Bool { true }

    static func absoluteURL(_ rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let direct = URL(string: rawValue), direct.scheme != nil { return direct }
        return URL(string: rawValue, relativeTo: apiBaseURL)?.absoluteURL
    }
}
