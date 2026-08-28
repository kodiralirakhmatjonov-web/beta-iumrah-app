import SwiftUI

struct SidebarDrawerView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var account: IumrahAccountStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            drawerHeader
            greeting
            profileCard

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    navigationRow(.home, title: L10n.text("tab_home", settings.language), icon: "house.fill")
                    navigationRow(.hotels, title: L10n.text("tab_hotels", settings.language), icon: "building.2.fill")
                    navigationRow(.booking, title: L10n.text("tab_booking", settings.language), icon: "suitcase.fill")
                    navigationRow(.care, title: "iumrah Care", icon: "heart.fill", careAccent: true)
                    navigationRow(.umrah, title: L10n.text("tab_umrah", settings.language), icon: "moon.stars.fill")

                    Divider()
                        .padding(.vertical, 12)

                    Button {
                        chrome.isAccountPresented = true
                        chrome.closeDrawer()
                    } label: {
                        settingsRow(
                            title: "iumrah ID",
                            value: account.iumrahID.map { "ID \($0)" } ?? accountSubtitle,
                            icon: "person.crop.circle.badge.checkmark"
                        )
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Picker(L10n.text("language_section", settings.language), selection: $settings.language) {
                            ForEach(AppSettingsStore.Language.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                    } label: {
                        settingsRow(
                            title: L10n.text("language_section", settings.language),
                            value: settings.language.title,
                            icon: "globe"
                        )
                    }

                    Menu {
                        Picker(L10n.text("appearance_section", settings.language), selection: $settings.appearance) {
                            ForEach(AppSettingsStore.Appearance.allCases) { appearance in
                                Text(appearance.title(settings.language)).tag(appearance)
                            }
                        }
                    } label: {
                        settingsRow(
                            title: L10n.text("appearance_section", settings.language),
                            value: settings.appearance.title(settings.language),
                            icon: "circle.lefthalf.filled"
                        )
                    }

                    Button {
                        chrome.isProfileEditorPresented = true
                        chrome.closeDrawer()
                    } label: {
                        settingsRow(
                            title: L10n.text("settings_title", settings.language),
                            value: nil,
                            icon: "gearshape.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(Color.iumrahCareLight)
                    .frame(width: 7, height: 7)
                Text("iumrah Project")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .background {
            ZStack {
                Color.iumrahCardBackground
                LinearGradient(
                    colors: [Color.iumrahCareLight.opacity(0.09), Color.clear, Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 34, topTrailingRadius: 34, style: .continuous))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(width: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 34, x: 14)
    }

    private var drawerHeader: some View {
        HStack(alignment: .center) {
            IumrahHeaderLogo(width: 164)
            Spacer(minLength: 12)
            Button {
                chrome.closeDrawer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 18)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text("drawer_greeting", settings.language))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)
            Text(L10n.text("drawer_welcome", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 28)
    }

    private var profileCard: some View {
        Button {
            chrome.isProfileEditorPresented = true
            chrome.closeDrawer()
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.iumrahCareLight.opacity(0.55), Color.iumrahCareDark.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "person.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareDark)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(settings.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(settings.hasBookingIdentity ? L10n.text("profile_subtitle_ready", settings.language) : L10n.text("profile_subtitle_empty", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.iumrahRaisedBackground.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
    }

    private var accountSubtitle: String {
        switch settings.language {
        case .russian: return "Войти в единый аккаунт"
        case .english: return "Sign in to your account"
        case .uzbek: return "Yagona akkauntga kirish"
        case .uzbekCyrillic: return "Ягона аккаунтга кириш"
        }
    }

    private func navigationRow(_ tab: AppTab, title: String, icon: String, careAccent: Bool = false) -> some View {
        Button {
            chrome.navigate(to: tab)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(careAccent ? Color.iumrahCareDark : Color.primary)
                    .frame(width: 34, height: 34)
                    .background(careAccent ? Color.iumrahCareLight.opacity(0.22) : Color.iumrahRaisedBackground)
                    .clipShape(Circle())

                Text(title)
                    .font(.body.weight(chrome.currentTab == tab ? .semibold : .medium))
                    .foregroundStyle(.primary)

                Spacer()

                if chrome.currentTab == tab {
                    Circle()
                        .fill(careAccent ? Color.iumrahCareLight : Color.primary)
                        .frame(width: 7, height: 7)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 52)
            .background(chrome.currentTab == tab ? Color.iumrahRaisedBackground.opacity(0.72) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func settingsRow(title: String, value: String?, icon: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .frame(height: 54)
        .contentShape(Rectangle())
    }
}
