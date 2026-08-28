import SwiftUI

enum AppTab: Hashable {
    case home
    case hotels
    case booking
    case care
    case account
}

final class AppChromeStore: ObservableObject {
    @Published var requestedTab: AppTab?
    @Published var currentTab: AppTab = .home
    @Published var shouldStartTripBuilder = false
    @Published var isImmersiveMode = false
    @Published private(set) var internalNavigationDepth = 0

    func navigate(to tab: AppTab) {
        requestedTab = tab
        currentTab = tab
        IumrahHaptics.selection()
    }

    func startNewTrip() {
        shouldStartTripBuilder = true
        currentTab = .booking
        requestedTab = .booking
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
