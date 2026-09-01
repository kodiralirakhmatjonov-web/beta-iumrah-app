import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct IumrahClientDevice: Codable, Hashable {
    let installationID: String
    let secret: String
    let name: String
    let model: String
    let platform: String
    let osVersion: String
    let appVersion: String
    let locale: String
}

enum IumrahAccountDeviceIdentity {
    private struct Credentials: Codable {
        let installationID: String
        let secret: String
    }

    private static let service = "com.iumrah.beta.account-device"
    private static let account = "installation"

    static func current(locale: String = Locale.current.identifier) -> IumrahClientDevice {
        let credentials = load() ?? create()
        let device = UIDevice.current
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return IumrahClientDevice(
            installationID: credentials.installationID,
            secret: credentials.secret,
            name: device.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "iPhone" : device.name,
            model: device.localizedModel,
            platform: device.systemName,
            osVersion: device.systemVersion,
            appVersion: build.isEmpty ? version : "\(version) (\(build))",
            locale: locale
        )
    }

    static func securityHeaders(token: String) -> [String: String] {
        let device = current()
        return [
            "Authorization": "Bearer \(token)",
            "x-iumrah-device-id": device.installationID,
            "x-iumrah-device-secret": device.secret,
        ]
    }

    private static func create() -> Credentials {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Secure random generation failed")
        let secret = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let credentials = Credentials(
            installationID: UUID().uuidString.lowercased(),
            secret: secret
        )
        save(credentials)
        return credentials
    }

    private static func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    private static func save(_ credentials: Credentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(base as CFDictionary, update as CFDictionary) == errSecSuccess { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(add as CFDictionary, nil)
    }
}

struct IumrahAppleCredential {
    let identityToken: String
    let nonce: String
}

enum IumrahAppleSignInError: LocalizedError {
    case secureRandomFailed
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .secureRandomFailed:
            return "Не удалось безопасно подготовить вход через Apple."
        case .invalidCredential:
            return "Apple не вернул подтверждение личности. Попробуйте ещё раз."
        }
    }
}

enum IumrahAppleSignInSupport {
    static func prepare(_ request: ASAuthorizationAppleIDRequest) throws -> String {
        let nonce = try randomNonce()
        // Apple email is requested only to resolve or create the same canonical
        // iumrah account. The permanent six-digit iumrah ID remains the profile ID.
        request.requestedScopes = [.email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return nonce
    }

    static func credential(from authorization: ASAuthorization, nonce: String) throws -> IumrahAppleCredential {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              !token.isEmpty,
              !nonce.isEmpty else {
            throw IumrahAppleSignInError.invalidCredential
        }
        return IumrahAppleCredential(identityToken: token, nonce: nonce)
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw IumrahAppleSignInError.secureRandomFailed
            }
            for byte in bytes where Int(byte) < characters.count {
                result.append(characters[Int(byte)])
                remaining -= 1
                if remaining == 0 { break }
            }
        }
        return result
    }
}
