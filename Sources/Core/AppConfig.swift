import Foundation

enum AppConfig {
    static let appName = "iumrah Beta"
    static let apiBaseURL = URL(string: "https://iumrah.app")!

    /// Flight inventory is resolved only through the iumrah backend, which keeps
    /// the Ignav API key in a Cloudflare Worker secret.
    static let flightInventoryConfigured = true

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
