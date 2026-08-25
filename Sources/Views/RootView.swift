import SwiftUI

struct RootView: View {
    enum AppTab: Hashable {
        case home
        case booking
        case care
        case umrah
    }

    @StateObject private var settings = AppSettingsStore()
    @StateObject private var chrome = AppChromeStore()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                TabView(selection: $selectedTab) {
                    AppNavigationContainer {
                        TripBuilderView()
                    }
                    .tag(AppTab.home)
                    .tabItem {
                        Label("Главная", systemImage: "house.fill")
                    }

                    AppNavigationContainer {
                        BookingsHomeView()
                    }
                    .tag(AppTab.booking)
                    .tabItem {
                        Label("Booking", systemImage: "suitcase.fill")
                    }

                    AppNavigationContainer {
                        CareHomeView()
                    }
                    .tag(AppTab.care)
                    .tabItem {
                        Label("Care", systemImage: "heart.fill")
                    }

                    AppNavigationContainer {
                        UmrahHomeView()
                    }
                    .tag(AppTab.umrah)
                    .tabItem {
                        Label("Umrah", systemImage: "book.closed.fill")
                    }
                }
                .tint(.primary)
                .toolbarBackground(Color.iumrahCardBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .onChange(of: selectedTab) { _, _ in
                    IumrahHaptics.selection()
                }
                .allowsHitTesting(!chrome.isDrawerOpen)

                if chrome.isDrawerOpen {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { chrome.closeDrawer() }
                        .transition(.opacity)

                    SidebarDrawerView()
                        .frame(width: min(proxy.size.width * 0.72, 330))
                        .frame(maxHeight: .infinity)
                        .ignoresSafeArea(edges: .vertical)
                        .transition(.move(edge: .leading))
                        .gesture(
                            DragGesture(minimumDistance: 12)
                                .onEnded { value in
                                    if value.translation.width < -48 {
                                        chrome.closeDrawer()
                                    }
                                }
                        )
                } else {
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: 18)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 12)
                                    .onEnded { value in
                                        if value.translation.width > 54 && abs(value.translation.height) < 80 {
                                            chrome.openDrawer()
                                        }
                                    }
                            )
                        Spacer(minLength: 0)
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .environmentObject(settings)
        .environmentObject(chrome)
        .preferredColorScheme(settings.preferredColorScheme)
        .background(Color.iumrahPageBackground)
    }
}
