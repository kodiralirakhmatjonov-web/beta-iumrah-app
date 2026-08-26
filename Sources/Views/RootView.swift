import SwiftUI

struct RootView: View {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var chrome = AppChromeStore()
    @StateObject private var journey = JourneyStore()
    @StateObject private var bookings = BookingStore()
    @ObservedObject private var push = PushNotificationManager.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                tabs
                    .allowsHitTesting(!chrome.isDrawerOpen)
                    .scaleEffect(chrome.isDrawerOpen ? 0.985 : 1, anchor: .trailing)
                    .offset(x: chrome.isDrawerOpen ? min(geometry.size.width * 0.08, 32) : 0)

                if chrome.isDrawerOpen {
                    Color.black.opacity(0.30)
                        .ignoresSafeArea()
                        .onTapGesture { chrome.closeDrawer() }
                        .transition(.opacity)

                    SidebarDrawerView()
                        .frame(width: min(max(geometry.size.width * 0.78, 286), 352))
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.width < -48 {
                                        chrome.closeDrawer()
                                    }
                                }
                        )
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: chrome.isDrawerOpen)
        }
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
        .task {
            await bookings.synchronizeCloud()
            await push.refreshAndRegisterIfAllowed()
            if let token = push.deviceToken { await bookings.registerPushDevice(token: token) }
        }
        .onChange(of: push.deviceToken) { _, token in
            guard let token else { return }
            Task { await bookings.registerPushDevice(token: token) }
        }
        .onChange(of: chrome.requestedTab) { _, newValue in
            guard let newValue else { return }
            chrome.currentTab = newValue
            chrome.requestedTab = nil
        }
        .onChange(of: chrome.isImmersiveMode) { _, immersive in
            if immersive && chrome.isDrawerOpen {
                chrome.closeDrawer()
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $chrome.currentTab) {
            tabScreen {
                HomeDashboardView()
            }
            .tabItem {
                Label(L10n.text("tab_home", settings.language), systemImage: "house")
            }
            .tag(AppTab.home)

            tabScreen {
                HotelsHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_hotels", settings.language), systemImage: "building.2")
            }
            .tag(AppTab.hotels)

            tabScreen {
                BookingsHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_booking", settings.language), systemImage: "suitcase")
            }
            .tag(AppTab.booking)

            tabScreen {
                CareHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_care", settings.language), systemImage: "heart.fill")
            }
            .tag(AppTab.care)

            tabScreen {
                UmrahHomeView()
            }
            .tabItem {
                Label(L10n.text("tab_umrah", settings.language), systemImage: "moon.stars")
            }
            .tag(AppTab.umrah)
        }
        .tint(.primary)
        .toolbar(chrome.isImmersiveMode ? .hidden : .visible, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.iumrahCardBackground.opacity(0.96), for: .tabBar)
    }

    private func tabScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        AppNavigationContainer { content() }
    }
}
