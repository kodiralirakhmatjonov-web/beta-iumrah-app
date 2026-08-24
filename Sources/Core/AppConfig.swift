import Foundation

enum AppConfig {
    static let appName = "iumrah"
    static let apiBaseURL = URL(string: "https://iumrah.app")!

    /// Temporary beta switch. The UI talks to protocols so this can be replaced
    /// by the real Flight Search Orchestrator without changing screens.
    static let usesSandboxFlightSearch = true

    /// Primary hotel assignments will ultimately be delivered by the backend.
    /// Until that endpoint exists, the app prefers the first published hotel
    /// matching the user's requested star class.
    static let usesLocalPrimaryHotelFallback = true

    static func absoluteURL(_ rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let direct = URL(string: rawValue), direct.scheme != nil { return direct }
        return URL(string: rawValue, relativeTo: apiBaseURL)?.absoluteURL
    }
}
