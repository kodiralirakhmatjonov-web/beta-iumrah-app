import SwiftUI

struct AppNavigationContainer<Content: View>: View {
    @EnvironmentObject private var chrome: AppChromeStore
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                IumrahHeaderLogo()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    chrome.openDrawer()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 25, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Профиль и меню")
            }
        }
        .toolbarBackground(Color.iumrahPageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
