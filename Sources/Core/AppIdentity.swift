import Foundation

enum AppIdentity {
    /// Immutable App Store identity inherited from the published iUmra app.
    static let productionBundleID = "com.iumrah.app"
    static let appStoreID = "6759577859"
    static let displayName = "iumrah"
    /// Runtime release version comes from the built app bundle. `project.yml` is
    /// the single source of truth for MARKETING_VERSION; do not duplicate it here.
    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Preserved from the Flutter production app.
    static let legacyURLScheme = "iumrah"

    /// Existing App Store product. The 1.0.x Flutter app bought this as a non-consumable.
    static let iumrahPlusProductID = "iumrah.plus"

    static var runtimeBundleID: String {
        Bundle.main.bundleIdentifier ?? productionBundleID
    }
}
