import Foundation
import Security

/// Makes app-owned Keychain credentials follow the lifetime of one installation.
///
/// iOS can preserve generic-password Keychain items after an app is deleted. That
/// is useful for some products, but iumrah treats a delete + reinstall as a fresh
/// local installation: no previous account session, booking tokens, or trusted
/// installation/device credential should silently come back.
///
/// A random marker is stored both inside the app container and in Keychain. The
/// container copy disappears when the app is deleted, while the Keychain copy may
/// survive. A missing/mismatched container marker therefore proves that the
/// Keychain state belongs to another installation and must be discarded.
enum AppInstallationLifecycle {
    private static let markerFilename = ".iumrah-installation-v1"
    private static let sentinelService = "com.iumrah.beta.installation-lifecycle"
    private static let sentinelAccount = "installation-marker-v1"
    private static let onboardingKey = "iumrah.hasCompletedOnboarding.cinematic.v4"

    private static let protectedItems: [(service: String, account: String)] = [
        ("com.iumrah.beta.iumrah-account", "session"),
        ("com.iumrah.beta.booking-sessions", "sessions"),
        ("com.iumrah.beta.account-device", "installation"),
        ("com.iumrah.beta.client-identity", "client-user-id"),
        ("com.iumrah.beta.client-identity", "stable-client-id"),
    ]

    static func prepare() {
        let diskMarker = readDiskMarker()
        let keychainMarker = readKeychainMarker()

        switch (diskMarker, keychainMarker) {
        case let (.some(local), .some(secure)) where local == secure:
            // Normal launch of the same installation.
            return

        case (.some, .some):
            // The container and secure state come from different installations.
            resetProtectedKeychainState()
            establishFreshMarker()

        case (.none, .some):
            // Keychain survived deletion while the app container did not.
            resetProtectedKeychainState()
            establishFreshMarker()

        case (.some(let local), .none):
            // Keychain was cleared independently while this app installation is
            // still present. Re-establish the sentinel without touching local data.
            saveKeychainMarker(local)

        case (.none, .none):
            // First launch after this lifecycle guard was introduced is ambiguous:
            // it may be a normal update of an existing installation or a reinstall
            // carrying legacy Keychain data. Existing installations that reached
            // the app have the onboarding flag in their container; a reinstalled
            // app does not. Preserve a real update, purge stale legacy credentials
            // on a fresh/reinstalled container.
            let existingInstallation = UserDefaults.standard.bool(forKey: onboardingKey)
            if !existingInstallation && containsProtectedKeychainState() {
                resetProtectedKeychainState()
            }
            establishFreshMarker()
        }
    }

    private static func establishFreshMarker() {
        let marker = UUID().uuidString.lowercased()
        // Never create a durable Keychain sentinel unless the matching
        // installation marker is safely present in the app container.
        guard saveDiskMarker(marker) else { return }
        saveKeychainMarker(marker)
    }

    private static var markerURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appendingPathComponent(markerFilename, isDirectory: false)
    }

    private static func readDiskMarker() -> String? {
        guard let url = markerURL,
              let data = try? Data(contentsOf: url),
              let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    @discardableResult
    private static func saveDiskMarker(_ value: String) -> Bool {
        guard let url = markerURL else { return false }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(value.utf8).write(to: url, options: .atomic)

            // This marker is installation state, not user content. Excluding it
            // from backup prevents a restored container from impersonating the
            // installation that originally created the Keychain credentials.
            do {
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var mutableURL = url
                try mutableURL.setResourceValues(resourceValues)
            } catch {
                // The marker itself is already written; backup exclusion failure
                // should not make account restoration unstable on every launch.
            }
            return true
        } catch {
            // Failing to persist the disk marker must never block app launch.
            return false
        }
    }

    private static func readKeychainMarker() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sentinelService,
            kSecAttrAccount as String: sentinelAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func saveKeychainMarker(_ value: String) {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sentinelService,
            kSecAttrAccount as String: sentinelAccount,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(base as CFDictionary, update as CFDictionary) == errSecSuccess { return }

        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(add as CFDictionary, nil)
    }

    private static func containsProtectedKeychainState() -> Bool {
        protectedItems.contains { item in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: item.service,
                kSecAttrAccount as String: item.account,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
        }
    }

    private static func resetProtectedKeychainState() {
        for item in protectedItems {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: item.service,
                kSecAttrAccount as String: item.account,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
