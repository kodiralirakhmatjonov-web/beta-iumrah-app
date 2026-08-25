import SwiftUI

enum AppTab: Hashable {
    case home
    case booking
    case care
    case umrah
}

final class AppChromeStore: ObservableObject {
    @Published var isDrawerOpen = false
    @Published var isProfileEditorPresented = false
    @Published var requestedTab: AppTab?
    @Published var shouldStartTripBuilder = false
    @Published var isImmersiveMode = false

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
        if isDrawerOpen { closeDrawer() }
        IumrahHaptics.selection()
    }


    func startNewTrip() {
        shouldStartTripBuilder = true
        requestedTab = .booking
        if isDrawerOpen { closeDrawer() }
        IumrahHaptics.selection()
    }

    func setImmersive(_ value: Bool) {
        guard isImmersiveMode != value else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isImmersiveMode = value
        }
    }
}
