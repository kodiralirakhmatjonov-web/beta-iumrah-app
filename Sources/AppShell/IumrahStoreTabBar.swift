import SwiftUI

/// Apple Store-inspired bottom chrome for the four primary destinations plus
/// a detached Account control. The tab selection still uses the existing
/// AppTab model and TabView architecture.
///
/// iOS 26+: native Liquid Glass only.
/// iOS 17–25: clean opaque fallback; no material/blur imitation.
struct IumrahStoreTabBar: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                nativeGlassBar
            } else {
                fallbackBar
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    @available(iOS 26.0, *)
    private var nativeGlassBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                mainTabs
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.interactive(true), in: Capsule())

                accountButton
                    .glassEffect(.regular.interactive(true), in: Circle())
            }
        }
    }

    private var fallbackBar: some View {
        HStack(spacing: 10) {
            mainTabs
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                }

            accountButton
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                }
        }
    }

    private var mainTabs: some View {
        HStack(spacing: 2) {
            tabButton(.booking, title: forYouTitle, systemName: "sparkles")
            tabButton(.home, title: productsTitle, systemName: "square.grid.2x2")
            tabButton(.hotels, title: hotelsTitle, systemName: "building.2")
            tabButton(.care, title: careTitle, systemName: "heart")
        }
    }

    private var accountButton: some View {
        Button {
            select(.account)
        } label: {
            Image(systemName: chrome.currentTab == .account ? "person.crop.circle.fill" : "person.crop.circle")
                .font(.system(size: 25, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(chrome.currentTab == .account ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.82))
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .background {
                    if chrome.currentTab == .account {
                        Circle()
                            .fill(Color(uiColor: .systemBlue).opacity(0.10))
                            .padding(5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accountTitle)
        .accessibilityAddTraits(chrome.currentTab == .account ? .isSelected : [])
    }

    private func tabButton(_ tab: AppTab, title: String, systemName: String) -> some View {
        let selected = chrome.currentTab == tab

        return Button {
            select(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: selected ? filledSymbol(for: systemName) : systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 21)

                Text(title)
                    .font(.system(size: 9.5, weight: selected ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .foregroundStyle(selected ? Color(uiColor: .systemBlue) : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                if selected {
                    Capsule().fill(Color(uiColor: .systemBlue).opacity(0.10))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func filledSymbol(for base: String) -> String {
        switch base {
        case "square.grid.2x2": return "square.grid.2x2.fill"
        case "building.2": return "building.2.fill"
        case "heart": return "heart.fill"
        default: return base
        }
    }

    private func select(_ tab: AppTab) {
        guard chrome.currentTab != tab else {
            IumrahHaptics.selection()
            return
        }
        withAnimation(.snappy(duration: 0.28)) {
            chrome.currentTab = tab
            chrome.requestedTab = nil
        }
        IumrahHaptics.selection()
    }

    private var forYouTitle: String { localized("Для Вас", "For You", "Siz uchun", "Сиз учун") }
    private var productsTitle: String { localized("Продукты", "Products", "Mahsulotlar", "Маҳсулотлар") }
    private var hotelsTitle: String { localized("Отели", "Hotels", "Mehmonxonalar", "Меҳмонхоналар") }
    private var careTitle: String { "Care" }
    private var accountTitle: String { localized("Аккаунт", "Account", "Hisob", "Ҳисоб") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}
