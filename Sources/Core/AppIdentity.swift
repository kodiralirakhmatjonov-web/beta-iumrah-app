import Foundation

enum AppIdentity {
    /// Immutable App Store identity inherited from the published iUmra app.
    static let productionBundleID = "com.iumrah.app"
    static let appStoreID = "6759577859"
    static let displayName = "iumrah"
    static let marketingVersion = "2.0.1"

    /// Preserved from the Flutter production app.
    static let legacyURLScheme = "iumrah"

    /// Existing App Store product. The 1.0.x Flutter app bought this as a non-consumable.
    static let iumrahPlusProductID = "iumrah.plus"

    static var runtimeBundleID: String {
        Bundle.main.bundleIdentifier ?? productionBundleID
    }
}
