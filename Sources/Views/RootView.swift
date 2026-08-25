import SwiftUI

struct RootView: View {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var chrome = AppChromeStore()
    @StateObject private var journey = JourneyStore()
    @StateObject private var bookings = BookingStore()

    var body: some View {
        TabView(selection: $chrome.currentTab) {
            tabScreen(.home) {
                HomeDashboardView()
            }
            .tabItem {
                Label(L10n.text("tab_home", settings.language), systemImage: "house")
            }
            .tag(AppTab.home)

            tabScreen(.hotels) {
                HotelsHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_hotels", settings.language), systemImage: "building.2")
            }
            .tag(AppTab.hotels)

            tabScreen(.booking) {
                BookingsHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_booking", settings.language), systemImage: "suitcase")
            }
            .tag(AppTab.booking)

            tabScreen(.care) {
                CareHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_care", settings.language), systemImage: "heart.text.square")
            }
            .tag(AppTab.care)

            tabScreen(.umrah) {
                UmrahHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_umrah", settings.language), systemImage: "moon.stars")
            }
            .tag(AppTab.umrah)
        }
        .tint(.primary)
        .toolbar(chrome.isImmersiveMode ? .hidden : .visible, for: .tabBar)
        .preferredColorScheme(settings.appearance.colorScheme)
        .environmentObject(settings)
        .environmentObject(chrome)
        .environmentObject(journey)
        .environmentObject(bookings)
        .sheet(isPresented: $chrome.isProfileEditorPresented) {
            ProfileSettingsView()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: chrome.requestedTab) { _, newValue in
            guard let newValue else { return }
            chrome.currentTab = newValue
            chrome.requestedTab = nil
        }
    }

    private func tabScreen<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        AppNavigationContainer(
            showsTabHeader: true,
            brandTab: tab,
            content: content
        )
    }
}
