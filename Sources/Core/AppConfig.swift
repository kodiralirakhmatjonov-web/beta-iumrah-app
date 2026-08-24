import Foundation

enum AppConfig {
    enum FlightEngineMode {
        case sandbox
        case officialWebBots
    }

    static let appName = "iumrah Beta"
    static let apiBaseURL = URL(string: "https://iumrah.app")!

    /// 0.5 technical state: the real bot engine is compiled into the beta app,
    /// but the current visible flow remains on sandbox until PackageQuote and
    /// CAPTCHA presentation are wired end-to-end. Flip only after backend deploy.
    static let flightEngineMode: FlightEngineMode = .sandbox
    static let flightBotMinimumOptions = 4
    static let flightBotPreferredOptions = 6

    /// Server-side Package Engine endpoint. Internal hotel/flight cost breakdown,
    /// markup and profit must never be returned to the consumer app.
    static let packageQuotePath = "/api/package/quote"
    static let usesRemotePackagePricing = false

    /// Primary hotel assignments will ultimately be delivered by the backend.
    /// Until that endpoint is deployed, the app prefers the first published hotel
    /// matching the user's requested star class.
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
