import SwiftUI

final class AppChromeStore: ObservableObject {
    @Published var isDrawerOpen = false
    @Published var isProfileEditorPresented = false

    func openDrawer() {
        guard !isDrawerOpen else { return }
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
}
