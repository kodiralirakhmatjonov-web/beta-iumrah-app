import SwiftUI

/// Store-style bottom navigation. It changes only presentation: the existing
/// AppTab cases and destination architecture remain intact.
struct IumrahStoreTabBar: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        IumrahGlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 1) {
                    tabButton(.booking, title: forYouTitle, systemName: "sparkles")
                    tabButton(.home, title: productsTitle, systemName: "square.grid.2x2.fill")
                    tabButton(.care, title: gearTitle, systemName: "suitcase.rolling.fill")
                    tabButton(.hotels, title: L10n.text("tab_hotels", settings.language), systemName: "building.2.fill")
                }
                .padding(6)
                .frame(maxWidth: .infinity)
                .iumrahGlass(in: Capsule(), interactive: false, chrome: true)

                Button {
                    select(.account)
                } label: {
                    Image(systemName: chrome.currentTab == .account ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.system(size: 23, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(chrome.currentTab == .account ? Color.primary : Color.primary.opacity(0.86))
                        .frame(width: 54, height: 54)
                        .contentShape(Circle())
                        .background {
                            if chrome.currentTab == .account {
                                Circle().fill(Color.primary.opacity(0.08)).padding(5)
                            }
                        }
                        .iumrahGlass(in: Circle(), interactive: true, chrome: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accountTitle)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 5)
        .padding(.bottom, 3)
    }

    private func tabButton(_ tab: AppTab, title: String, systemName: String) -> some View {
        let selected = chrome.currentTab == tab

        return Button {
            select(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 21)

                Text(title)
                    .font(.system(size: 9.5, weight: selected ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                if selected {
                    Capsule().fill(Color.primary.opacity(0.08))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
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

    private var forYouTitle: String {
        localized("Для Вас", "For You", "Siz uchun", "Сиз учун")
    }

    private var productsTitle: String {
        localized("Продукты", "Products", "Mahsulotlar", "Маҳсулотлар")
    }

    private var gearTitle: String {
        localized("Подготовка", "Gear", "Tayyorgarlik", "Тайёргарлик")
    }

    private var accountTitle: String {
        localized("Аккаунт", "Account", "Hisob", "Ҳисоб")
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}
