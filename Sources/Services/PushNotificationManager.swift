import Combine
import Foundation
import UIKit
import UserNotifications

struct IumrahPushEvent: Equatable {
    let type: String
    let bookingID: String?
    let status: String?
}

@MainActor
final class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?
    @Published private(set) var lastError: String?
    @Published private(set) var lastEvent: IumrahPushEvent?
    @Published private(set) var eventRevision: Int = 0

    private let tokenDefaultsKey = "iumrah.beta.apns.device-token"

    private init() {
        deviceToken = UserDefaults.standard.string(forKey: tokenDefaultsKey)
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func statusText(language: AppSettingsStore.Language) -> String {
        switch authorizationStatus {
        case .notDetermined:
            return L10n.text("notifications_not_determined", language)
        case .denied:
            return L10n.text("notifications_denied", language)
        case .authorized:
            return deviceToken == nil
                ? L10n.text("notifications_registering", language)
                : L10n.text("notifications_enabled", language)
        case .provisional:
            return L10n.text("notifications_provisional", language)
        case .ephemeral:
            return L10n.text("notifications_ephemeral", language)
        @unknown default:
            return L10n.text("notifications_unknown", language)
        }
    }

    func refreshAndRegisterIfAllowed() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus

        if isAuthorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func ensureAuthorizationForBookedTrips(hasBookings: Bool) async {
        await refreshAndRegisterIfAllowed()
        guard hasBookings, authorizationStatus == .notDetermined else { return }
        await requestAuthorization()
    }

    func requestAuthorization() async {
        lastError = nil

        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAndRegisterIfAllowed()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func didRegister(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
        lastError = nil

        #if DEBUG
        print("[iumrah Beta] APNs device token registered")
        #endif
    }

    func didFailToRegister(error: Error) {
        lastError = error.localizedDescription
        #if DEBUG
        print("[iumrah Beta] APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    func receiveRemotePayload(_ userInfo: [AnyHashable: Any]) {
        let type = (userInfo["type"] as? String) ?? "notification"
        let bookingID = userInfo["bookingID"] as? String
        let status = userInfo["status"] as? String
        lastEvent = IumrahPushEvent(type: type, bookingID: bookingID, status: status)
        eventRevision &+= 1
    }
}
