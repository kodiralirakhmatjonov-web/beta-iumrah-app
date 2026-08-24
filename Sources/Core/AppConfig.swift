import Foundation

enum AppConfig {
    enum FlightEngineMode: Equatable {
        case sandbox
        case automatic
        case officialWebBots
    }

    static let appName = "iumrah Beta"
    static let apiBaseURL = URL(string: "https://iumrah.app")!

    /// 0.6 technical state. Automatic mode checks the server-side Package Engine
    /// first. If it is not deployed/configured yet, the existing sandbox remains
    /// available so TestFlight never becomes unusable.
    static let flightEngineMode: FlightEngineMode = .automatic
    static let flightBotMinimumOptions = 4
    static let flightBotPreferredOptions = 6

    static let packageHealthPath = "/api/package/health"
    static let packageQuotePath = "/api/package/quote"
    static let packageFlightOptionsQuotePath = "/api/package/flight-options/quote"
    static let usesRemotePackagePricing = true

    /// Primary hotel assignments are resolved server-side from the package tier,
    /// hotel stars and existing iumrah Hotels D1 catalog.
    static let usesLocalPrimaryHotelFallback = true

    static var usesSandboxFlightSearch: Bool {
        flightEngineMode == .sandbox
    }

    static func absoluteURL(_ rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let direct = URL(string: rawValue), direct.scheme != nil { return direct }
        return URL(string: rawValue, relativeTo: apiBaseURL)?.absoluteURL
    }
}
