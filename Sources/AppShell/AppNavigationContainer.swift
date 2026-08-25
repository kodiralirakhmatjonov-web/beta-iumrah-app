import SwiftUI

struct AppNavigationContainer<Content: View>: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    let showsTabHeader: Bool
    let brandTab: AppTab
    let content: Content

    init(
        showsTabHeader: Bool = true,
        brandTab: AppTab = .home,
        @ViewBuilder content: () -> Content
    ) {
        self.showsTabHeader = showsTabHeader
        self.brandTab = brandTab
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if showsTabHeader && !chrome.isImmersiveMode && !chrome.isInternalNavigationActive {
                        BrandHeader(
                            accessibilityLabel: L10n.text("profile_accessibility", settings.language),
                            profileAction: { chrome.isProfileEditorPresented = true }
                        )
                    }
                }
                .background(Color.iumrahPageBackground.ignoresSafeArea())
        }
    }
}

private struct BrandHeader: View {
    let accessibilityLabel: String
    let profileAction: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.iumrahPageBackground, Color.iumrahPageBackground.opacity(0.94), Color.iumrahPageBackground.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 112)

            HStack(spacing: 12) {
                IumrahHeaderLogo(width: 158)
                Spacer()
                Button(action: profileAction) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.iumrahCardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
    }
}
