import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("iumrah.hasCompletedOnboarding.cinematic.v4") private var hasCompletedOnboarding = false
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var chrome = AppChromeStore()
    @StateObject private var journey = JourneyStore()
    @StateObject private var bookings = BookingStore()
    @StateObject private var account = IumrahAccountStore()
    @ObservedObject private var push = PushNotificationManager.shared
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared
    @State private var hasBootstrappedAfterOnboarding = false

    var body: some View {
        rootContent
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
                guard hasCompletedOnboarding else { return }
                await bootstrapAfterOnboardingIfNeeded()
                await push.ensureAuthorizationForClientNotifications()
                await syncPushSubscriptions()
                await syncClientNotifications()
                handleOpenedPushIfNeeded()
            }
            .onChange(of: push.deviceToken) { _, _ in
                guard hasCompletedOnboarding else { return }
                Task {
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: bookings.sessions.map(\.id)) { _, _ in
                Task {
                    await linkLocalBookingsToAccount()
                    guard hasCompletedOnboarding else { return }
                    await push.ensureAuthorizationForClientNotifications()
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: account.iumrahID) { _, newValue in
                bookings.setAccountToken(account.bearerToken)
                syncLocalProfileFromAccount()
                Task { await syncClientNotifications() }
                guard newValue != nil, let token = account.bearerToken else { return }
                Task {
                    await bookings.restoreAccountTrips(token: token)
                    await linkLocalBookingsToAccount()
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: settings.language.rawValue) { _, _ in
                guard hasCompletedOnboarding else { return }
                Task {
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: hasCompletedOnboarding) { _, completed in
                guard completed else { return }
                Task {
                    await bootstrapAfterOnboardingIfNeeded()
                    await push.ensureAuthorizationForClientNotifications()
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                    handleOpenedPushIfNeeded()
                }
            }
            .onChange(of: push.eventRevision) { _, _ in
                guard hasCompletedOnboarding else { return }
                Task {
                    await bookings.refreshAll()
                    await clientNotifications.refresh(accountToken: account.bearerToken)
                    if let bookingID = push.lastEvent?.bookingID,
                       push.lastEvent?.type.hasPrefix("chat_") == true {
                        _ = try? await bookings.loadChat(for: bookingID)
                    }
                }
            }
            .onChange(of: push.openRevision) { _, _ in
                guard hasCompletedOnboarding else { return }
                handleOpenedPushIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, hasCompletedOnboarding else { return }
                Task {
                    await push.refreshAndRegisterIfAllowed()
                    await syncClientNotifications()
                }
            }
    }

    @MainActor
    private func bootstrapAfterOnboardingIfNeeded() async {
        guard !hasBootstrappedAfterOnboarding else { return }
        hasBootstrappedAfterOnboarding = true

        // Keep the cinematic first launch independent from account/network restoration.
        // This prevents stale sessions or slow network calls from competing with the intro.
        await account.restore()
        syncLocalProfileFromAccount()
        bookings.setAccountToken(account.bearerToken)

        if let token = account.bearerToken {
            await bookings.restoreAccountTrips(token: token)
            await linkLocalBookingsToAccount()
        }

        await bookings.refreshAll()
    }

    @MainActor
    private func syncPushSubscriptions() async {
        guard let token = push.deviceToken, !token.isEmpty else { return }
        await bookings.syncPushSubscriptions(deviceToken: token, locale: settings.language.rawValue)
    }

    @MainActor
    private func syncClientNotifications() async {
        await clientNotifications.sync(
            deviceToken: push.deviceToken,
            accountToken: account.bearerToken,
            hasTrip: !bookings.sessions.isEmpty,
            locale: settings.language.rawValue
        )
    }

    @MainActor
    private func handleOpenedPushIfNeeded() {
        guard let event = push.lastOpenedEvent else { return }
        if event.type == "system_notification" {
            routeNotification(destination: event.destination, bookingID: event.destinationBookingID)
            if let id = event.notificationID, let notification = clientNotifications.notification(id: id) {
                Task { await clientNotifications.markOpened(notification, accountToken: account.bearerToken) }
            }
            return
        }
        if let bookingID = event.bookingID {
            if event.type.hasPrefix("chat_") {
                chrome.navigate(to: .care)
            } else {
                chrome.openBooking(id: bookingID)
            }
        }
    }

    @MainActor
    private func routeNotification(destination: String?, bookingID: String?) {
        switch destination {
        case "hotels": chrome.navigate(to: .hotels)
        case "bookings": chrome.navigate(to: .booking)
        case "care": chrome.navigate(to: .care)
        case "account": chrome.navigate(to: .account)
        case "booking":
            if let bookingID, bookings.booking(id: bookingID) != nil { chrome.openBooking(id: bookingID) }
            else { chrome.navigate(to: .booking) }
        default: chrome.navigate(to: .home)
        }
    }

    @MainActor
    private func linkLocalBookingsToAccount() async {
        guard account.isAuthenticated else { return }
        for session in bookings.sessions {
            let bookingToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bookingToken.isEmpty else { continue }
            if let linked = try? await account.linkBooking(bookingID: session.id, bookingToken: bookingToken) {
                bookings.applyCanonicalLink(linked, to: session.id)
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


    private var rootContent: some View {
        Group {
            if hasCompletedOnboarding {
                SidebarDrawerHost { tabs }
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                OnboardingFlowView {
                    withAnimation(.easeInOut(duration: 0.34)) {
                        hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.015)))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: hasCompletedOnboarding)
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
        // Navigation chrome uses one restrained app accent; content icons carry
        // the richer semantic palette. This keeps the native tab bar adult and legible.
        .tint(IumrahIconRole.umrah.color)
        .toolbar((chrome.isImmersiveMode || chrome.isInternalNavigationActive) ? .hidden : .visible, for: .tabBar)
        .fullScreenCover(isPresented: $chrome.isESIMPresented) {
            ESIMView()
                .environmentObject(settings)
                .environmentObject(chrome)
                .environmentObject(bookings)
        }
    }

    private func tabScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        AppNavigationContainer { content() }
    }
}
