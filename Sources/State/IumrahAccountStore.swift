import Foundation
import Security
import Combine

@MainActor
final class IumrahAccountStore: ObservableObject {
    @Published private(set) var account: IumrahAccountProfile?
    @Published private(set) var isRestoring = false
    @Published private(set) var lastError: String?

    private let service = IumrahAccountService()
    private var token: String?

    init() {
        LegacyClientIdentityCleanup.purge()
        if let saved = IumrahAccountVault.load() {
            token = saved.token
            account = saved.account
        }
    }

    var isAuthenticated: Bool { token != nil && account != nil }
    var iumrahID: String? { account?.iumrahID }
    var bearerToken: String? { token }

    func authorizationHeaders(bookingToken: String? = nil) -> [String: String] {
        var headers: [String: String] = [:]
        if let token, !token.isEmpty { headers["Authorization"] = "Bearer \(token)" }
        if let bookingToken, !bookingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers["x-booking-token"] = bookingToken
        }
        return headers
    }

    func restore() async {
        guard let token else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let profile = try await service.session(token: token)
            account = profile
            IumrahAccountVault.save(.init(token: token, account: profile))
            lastError = nil
        } catch {
            self.token = nil
            account = nil
            IumrahAccountVault.clear()
            lastError = nil
        }
    }

    @discardableResult
    func activate(bookingID: String, bookingToken: String, password: String) async throws -> IumrahAccountProfile {
        let response = try await service.activate(bookingID: bookingID, bookingToken: bookingToken, password: password)
        setSession(response)
        return response.account
    }

    @discardableResult
    func login(iumrahID: String, password: String) async throws -> IumrahAccountProfile {
        let response = try await service.login(iumrahID: iumrahID, password: password)
        setSession(response)
        return response.account
    }

    @discardableResult
    func updateProfile(firstName: String, lastName: String, phone: String, email: String, telegram: String, whatsapp: String) async throws -> IumrahAccountProfile {
        guard let token else { throw APIError.status(401) }
        let profile = try await service.updateProfile(
            .init(firstName: firstName, lastName: lastName, phone: phone, email: email, telegram: telegram, whatsapp: whatsapp),
            token: token
        )
        account = profile
        lastError = nil
        IumrahAccountVault.save(.init(token: token, account: profile))
        return profile
    }

    func logout() async {
        if let token { await service.logout(token: token) }
        token = nil
        account = nil
        lastError = nil
        IumrahAccountVault.clear()
    }

    func linkBooking(bookingID: String, bookingToken: String) async throws -> String {
        guard let token else { throw APIError.status(401) }
        return try await service.linkBooking(bookingID: bookingID, bookingToken: bookingToken, token: token)
    }

    func accountTrips() async throws -> [ClientTripSnapshot] {
        guard let token else { throw APIError.status(401) }
        return try await service.trips(token: token)
    }

    func tripDetail(bookingID: String) async throws -> IumrahAccountTripDetailResponse {
        guard let token else { throw APIError.status(401) }
        return try await service.tripDetail(bookingID: bookingID, token: token)
    }

    private func setSession(_ response: IumrahAccountAuthResponse) {
        token = response.session.token
        account = response.account
        lastError = nil
        IumrahAccountVault.save(.init(token: response.session.token, account: response.account))
    }
}

private struct StoredIumrahAccountSession: Codable {
    let token: String
    let account: IumrahAccountProfile
}

private enum IumrahAccountVault {
    private static let service = "com.iumrah.beta.iumrah-account"
    private static let account = "session"

    static func load() -> StoredIumrahAccountSession? {
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
        return try? JSONDecoder().decode(StoredIumrahAccountSession.self, from: data)
    }

    static func save(_ value: StoredIumrahAccountSession) {
        guard let data = try? JSONEncoder().encode(value) else { return }
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

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
