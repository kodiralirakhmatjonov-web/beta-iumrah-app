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
                .toolbarBackground(Color.iumrahPageBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !chrome.isImmersiveMode {
                IumrahPersistentHeader()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

private struct IumrahPersistentHeader: View {
    @EnvironmentObject private var chrome: AppChromeStore

    var body: some View {
        HStack(spacing: 12) {
            IumrahHeaderLogo(width: 118)
            Spacer(minLength: 0)
            Button {
                chrome.openDrawer()
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(.primary.opacity(0.06), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Профиль и меню")
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color.iumrahPageBackground.opacity(0.94))
    }
}
