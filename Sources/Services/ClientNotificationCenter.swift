import Foundation
import Combine

struct ClientSystemNotification: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let targetScope: String
    let destination: String
    let destinationBookingID: String?
    let createdBy: String
    let status: String
    let matchedDevices: Int
    let pushSentCount: Int
    let pushFailedCount: Int
    let createdAt: String
    let sentAt: String?
    let expiresAt: String
    var isRead: Bool
}

private struct ClientNotificationDeviceRegistration: Encodable {
    let installationID: String
    let deviceToken: String?
    let environment: String
    let appBundleID: String
    let locale: String
    let hasTrip: Bool
}

private struct ClientNotificationDeviceResponse: Decodable {
    let ok: Bool
    let ready: Bool?
}

private struct ClientNotificationFeedResponse: Decodable {
    let ok: Bool
    let notifications: [ClientSystemNotification]
}

private struct ClientNotificationReadRequest: Encodable {
    let installationID: String
}

private struct ClientNotificationReadResponse: Decodable {
    let ok: Bool
}

@MainActor
final class ClientNotificationCenter: ObservableObject {
    static let shared = ClientNotificationCenter()

    @Published private(set) var notifications: [ClientSystemNotification] = []
    @Published private(set) var latest: ClientSystemNotification?
    @Published private(set) var lastError: String?

    private let api = APIClient.shared
    private let installationKey = "iumrah.beta.client-notification-installation.v1"
    private let cacheKey = "iumrah.beta.client-notification-cache.v1"
    private(set) lazy var installationID: String = resolvedInstallationID()

    private init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([ClientSystemNotification].self, from: data) {
            notifications = cached
            latest = cached.first
        }
    }

    func sync(deviceToken: String?, accountToken: String?, hasTrip: Bool, locale: String) async {
        let headers = authorizationHeaders(accountToken)
        do {
            let _: ClientNotificationDeviceResponse = try await api.post(
                "/api/catalog/hotels/client/notifications/devices",
                body: ClientNotificationDeviceRegistration(
                    installationID: installationID,
                    deviceToken: normalizedToken(deviceToken),
                    environment: "production",
                    appBundleID: "com.iumrah.beta",
                    locale: locale,
                    hasTrip: hasTrip
                ),
                headers: headers
            )
            await refresh(accountToken: accountToken)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh(accountToken: String?) async {
        do {
            let response: ClientNotificationFeedResponse = try await api.get(
                "/api/catalog/hotels/client/notifications/feed",
                query: [URLQueryItem(name: "installationID", value: installationID)],
                headers: authorizationHeaders(accountToken)
            )
            notifications = response.notifications
            latest = response.notifications.first
            persistCache()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func markOpened(_ notification: ClientSystemNotification, accountToken: String?) async {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            latest = notifications.first
            persistCache()
        }
        let headers = authorizationHeaders(accountToken)
        let _: ClientNotificationReadResponse? = try? await api.post(
            "/api/catalog/hotels/client/notifications/feed/\(notification.id)/read",
            body: ClientNotificationReadRequest(installationID: installationID),
            headers: headers
        )
    }

    func notification(id: String) -> ClientSystemNotification? {
        notifications.first { $0.id == id }
    }

    private func normalizedToken(_ token: String?) -> String? {
        let value = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value.lowercased()
    }

    private func authorizationHeaders(_ token: String?) -> [String: String] {
        let value = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? [:] : ["Authorization": "Bearer \(value)"]
    }

    private func resolvedInstallationID() -> String {
        if let existing = UserDefaults.standard.string(forKey: installationKey), existing.count >= 16 {
            return existing
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: installationKey)
        return value
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(Array(notifications.prefix(12))) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
