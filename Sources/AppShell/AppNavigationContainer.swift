import SwiftUI

struct AppNavigationContainer<Content: View>: View {
    @EnvironmentObject private var chrome: AppChromeStore
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
                    if showsTabHeader {
                        BrandHeader {
                            chrome.isProfileEditorPresented = true
                        }
                    }
                }
                .background(Color.iumrahPageBackground.ignoresSafeArea())
        }
    }
}

private struct BrandHeader: View {
    let profileAction: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.iumrahPageBackground, Color.iumrahPageBackground.opacity(0.92), Color.iumrahPageBackground.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 104)
            HStack(spacing: 12) {
                IumrahHeaderLogo(width: 142)
                Spacer()
                Button(action: profileAction) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(Color.iumrahCardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.primary.opacity(0.07), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile")
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
    }
}
