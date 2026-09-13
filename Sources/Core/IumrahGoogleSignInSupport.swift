import Foundation
import GoogleSignIn
import Security
import UIKit

struct IumrahGoogleCredential {
    let identityToken: String
    let nonce: String
}

enum IumrahGoogleSignInError: LocalizedError {
    case notConfigured
    case noPresentationContext
    case secureRandomFailed
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sign-In ещё не настроен для этой сборки. Добавьте OAuth Client ID по инструкции GOOGLE_SIGNIN_SETUP.md."
        case .noPresentationContext:
            return "Не удалось открыть окно входа Google. Попробуйте ещё раз."
        case .secureRandomFailed:
            return "Не удалось безопасно подготовить вход через Google."
        case .invalidCredential:
            return "Google не вернул подтверждение личности. Попробуйте ещё раз."
        }
    }
}

@MainActor
enum IumrahGoogleSignInSupport {
    static func signIn() async throws -> IumrahGoogleCredential {
        let clientID = configuredValue(for: "GIDClientID")
        let serverClientID = configuredValue(for: "GIDServerClientID")
        guard let clientID, let serverClientID, hasCallbackURLScheme(for: clientID) else {
            throw IumrahGoogleSignInError.notConfigured
        }
        guard let presenter = presentationViewController() else {
            throw IumrahGoogleSignInError.noPresentationContext
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
        )

        let nonce = try randomNonce()
        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: [],
                nonce: nonce
            ) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: IumrahGoogleSignInError.invalidCredential)
                    return
                }
                continuation.resume(returning: result)
            }
        }

        guard let identityToken = result.user.idToken?.tokenString,
              !identityToken.isEmpty else {
            throw IumrahGoogleSignInError.invalidCredential
        }

        return IumrahGoogleCredential(identityToken: identityToken, nonce: nonce)
    }

    static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == kGIDSignInErrorDomain && nsError.code == -5
    }

    static func signOutProviderSession() {
        GIDSignIn.sharedInstance.signOut()
    }

    private static func configuredValue(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("__GOOGLE_") else { return nil }
        return value
    }

    private static func hasCallbackURLScheme(for clientID: String) -> Bool {
        let expected = clientID
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
        guard !expected.isEmpty,
              let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }
        return urlTypes.contains { item in
            guard let schemes = item["CFBundleURLSchemes"] as? [String] else { return false }
            return schemes.contains(expected)
        }
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw IumrahGoogleSignInError.secureRandomFailed
            }
            for byte in bytes where Int(byte) < characters.count {
                result.append(characters[Int(byte)])
                remaining -= 1
                if remaining == 0 { break }
            }
        }
        return result
    }

    private static func presentationViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        return visibleViewController(from: root)
    }

    private static func visibleViewController(from controller: UIViewController?) -> UIViewController? {
        guard let controller else { return nil }
        if let presented = controller.presentedViewController {
            return visibleViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController {
            return visibleViewController(from: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return visibleViewController(from: tab.selectedViewController)
        }
        return controller
    }
}
