import Foundation

enum AppConfig {
    static let appName = "iumrah Beta"
    static let apiBaseURL = URL(string: "https://iumrah.app")!

    /// Intentionally false in cleanup update 013. The next update will inject
    /// one Ignav-backed implementation through FlightInventoryProviding.
    static let flightInventoryConfigured = false

    static let hotelPriceProviderTimeoutSeconds: Double = 17
    static let hotelPriceSearchHardTimeoutSeconds: Double = 46

    static let packageHealthPath = "/api/package/health"
    static let packageBookingPath = "/api/bookings"
    static let usesServerPrimaryHotelResolver = true
    static let usesLocalPrimaryHotelFallback = true

    static func absoluteURL(_ rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let direct = URL(string: rawValue), direct.scheme != nil { return direct }
        return URL(string: rawValue, relativeTo: apiBaseURL)?.absoluteURL
    }
}
