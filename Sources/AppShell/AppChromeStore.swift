import SwiftUI

enum AppTab: Hashable {
    case home
    case hotels
    case booking
    case care
    case umrah
}

final class AppChromeStore: ObservableObject {
    @Published var isDrawerOpen = false
    @Published var isProfileEditorPresented = false
    @Published var isAccountPresented = false
    @Published var requestedTab: AppTab?
    @Published var currentTab: AppTab = .home
    @Published var shouldStartTripBuilder = false
    @Published var isImmersiveMode = false
    @Published private(set) var internalNavigationDepth = 0

    func openDrawer() {
        guard !isDrawerOpen, !isImmersiveMode else { return }
        IumrahHaptics.soft()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            isDrawerOpen = true
        }
    }

    func closeDrawer() {
        guard isDrawerOpen else { return }
        IumrahHaptics.soft()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isDrawerOpen = false
        }
    }

    func navigate(to tab: AppTab) {
        requestedTab = tab
        currentTab = tab
        if isDrawerOpen { closeDrawer() }
        IumrahHaptics.selection()
    }

    func startNewTrip() {
        shouldStartTripBuilder = true
        currentTab = .booking
        requestedTab = .booking
        if isDrawerOpen { closeDrawer() }
        IumrahHaptics.selection()
    }

    var isInternalNavigationActive: Bool { internalNavigationDepth > 0 }

    func beginInternalNavigation() {
        internalNavigationDepth += 1
    }

    func endInternalNavigation() {
        internalNavigationDepth = max(0, internalNavigationDepth - 1)
    }

    func setImmersive(_ value: Bool) {
        guard isImmersiveMode != value else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isImmersiveMode = value
        }
    }
}
