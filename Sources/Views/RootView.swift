import SwiftUI

struct RootView: View {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var chrome = AppChromeStore()
    @StateObject private var journey = JourneyStore()
    @StateObject private var bookings = BookingStore()
    @StateObject private var account = IumrahAccountStore()
    @ObservedObject private var push = PushNotificationManager.shared

    var body: some View {
        tabs
            .preferredColorScheme(settings.appearance.colorScheme)
            .environmentObject(settings)
            .environmentObject(chrome)
            .environmentObject(journey)
            .environmentObject(bookings)
            .environmentObject(account)
            .onChange(of: chrome.requestedTab) { _, newValue in
                guard let newValue else { return }
                chrome.currentTab = newValue
                chrome.requestedTab = nil
            }
            .task {
                await account.restore()
                syncLocalProfileFromAccount()
                bookings.setAccountToken(account.bearerToken)
                if let token = account.bearerToken {
                    await bookings.restoreAccountTrips(token: token)
                    await linkLocalBookingsToAccount()
                }
                await bookings.refreshAll()
                await push.ensureAuthorizationForBookedTrips(hasBookings: !bookings.sessions.isEmpty)
                await syncPushSubscriptions()
            }
            .onChange(of: push.deviceToken) { _, _ in
                Task { await syncPushSubscriptions() }
            }
            .onChange(of: bookings.sessions.map(\.id)) { _, _ in
                Task {
                    await linkLocalBookingsToAccount()
                    await push.ensureAuthorizationForBookedTrips(hasBookings: !bookings.sessions.isEmpty)
                    await syncPushSubscriptions()
                }
            }
            .onChange(of: account.iumrahID) { _, newValue in
                bookings.setAccountToken(account.bearerToken)
                syncLocalProfileFromAccount()
                guard newValue != nil, let token = account.bearerToken else { return }
                Task {
                    await bookings.restoreAccountTrips(token: token)
                    await linkLocalBookingsToAccount()
                    await syncPushSubscriptions()
                }
            }
            .onChange(of: settings.language.rawValue) { _, _ in
                Task { await syncPushSubscriptions() }
            }
            .onChange(of: push.eventRevision) { _, _ in
                Task {
                    await bookings.refreshAll()
                    if let bookingID = push.lastEvent?.bookingID,
                       push.lastEvent?.type.hasPrefix("chat_") == true {
                        _ = try? await bookings.loadChat(for: bookingID)
                    }
                }
            }
    }

    @MainActor
    private func syncPushSubscriptions() async {
        guard let token = push.deviceToken, !token.isEmpty else { return }
        await bookings.syncPushSubscriptions(deviceToken: token, locale: settings.language.rawValue)
    }

    @MainActor
    private func linkLocalBookingsToAccount() async {
        guard account.isAuthenticated else { return }
        for session in bookings.sessions {
            let bookingToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bookingToken.isEmpty else { continue }
            if let canonicalID = try? await account.linkBooking(bookingID: session.id, bookingToken: bookingToken) {
                bookings.applyCanonicalPilgrimID(canonicalID, to: session.id)
            }
        }
    }

    @MainActor
    private func syncLocalProfileFromAccount() {
        guard let profile = account.account else { return }
        if settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.firstName = profile.firstName
        }
        if settings.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.lastName = profile.lastName
        }
        if settings.telegram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.telegram = profile.telegram
        }
        if settings.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.whatsapp = profile.whatsapp.isEmpty ? profile.phone : profile.whatsapp
        }
    }

    private var tabs: some View {
        TabView(selection: $chrome.currentTab) {
            tabScreen { HomeDashboardView() }
                .tabItem { Label(L10n.text("tab_home", settings.language), systemImage: "house") }
                .tag(AppTab.home)

            tabScreen { HotelsHomeView() }
                .tabItem { Label(L10n.text("tab_hotels", settings.language), systemImage: "building.2") }
                .tag(AppTab.hotels)

            tabScreen { BookingsHomeView() }
                .tabItem { Label(L10n.text("tab_booking", settings.language), systemImage: "suitcase") }
                .tag(AppTab.booking)

            tabScreen { CareHomeView() }
                .tabItem { Label(L10n.text("tab_care", settings.language), systemImage: "heart.fill") }
                .tag(AppTab.care)

            tabScreen { IumrahAccountView() }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(AppTab.account)
        }
        .tint(.primary)
        .toolbar((chrome.isImmersiveMode || chrome.isInternalNavigationActive) ? .hidden : .visible, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.iumrahCardBackground.opacity(0.96), for: .tabBar)
    }

    private func tabScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        AppNavigationContainer { content() }
    }
}
