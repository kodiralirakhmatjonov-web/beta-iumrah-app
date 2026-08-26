import Foundation

enum AppConfig {
    enum FlightEngineMode: Equatable {
        case sandbox
        case automatic
        case officialWebBots
    }

    static let appName = "iumrah Beta"
    static let apiBaseURL = URL(string: "https://iumrah.app")!

    /// 0.9 TestFlight validation mode: real provider bots + server-side package pricing.
    /// There is deliberately NO silent sandbox fallback in this mode. If a provider,
    /// CAPTCHA or Package Engine fails, the beta must expose that failure so we can tune it.
    static let flightEngineMode: FlightEngineMode = .officialWebBots
    static let flightBotMinimumOptions = 4
    static let flightBotPreferredOptions = 6
    static let flightBotProviderBatchSize = 4
    static let flightBotProviderTimeoutSeconds: Double = 11
    static let flightBotSearchHardTimeoutSeconds: Double = 58
    static let flightSearchScreenHardTimeoutSeconds: Double = 88

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

    static var isStrictRealFlightTest: Bool {
        flightEngineMode == .officialWebBots
    }

    static func absoluteURL(_ rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let direct = URL(string: rawValue), direct.scheme != nil { return direct }
        return URL(string: rawValue, relativeTo: apiBaseURL)?.absoluteURL
    }
}
