import SwiftUI

struct SidebarDrawerView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                IumrahHeaderLogo(width: 128)
                Spacer()
                Button {
                    chrome.closeDrawer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 28)

            Text(settings.language == .english ? "Assalamu alaikum" : settings.language == .uzbek ? "Assalomu alaykum" : settings.language == .uzbekCyrillic ? "Ассалому алайкум" : "Ассаляму алейкум")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(settings.language == .english ? "Welcome to iumrah" : settings.language == .uzbek ? "iumrah'ga xush kelibsiz" : settings.language == .uzbekCyrillic ? "iumrah'га хуш келибсиз" : "Добро пожаловать в iumrah")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            profileCard
                .padding(.top, 22)

            VStack(spacing: 6) {
                drawerRow(settings.language == .english ? "Chats" : settings.language == .uzbek ? "Chatlar" : settings.language == .uzbekCyrillic ? "Чатлар" : "Чаты", systemImage: "bubble.left.and.bubble.right") {
                    chrome.navigate(to: .care)
                }

                Menu {
                    Picker(L10n.text("language_section", settings.language), selection: $settings.language) {
                        ForEach(AppSettingsStore.Language.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                } label: {
                    drawerLabel("\(L10n.text("language_section", settings.language)) · \(settings.language.title)", systemImage: "globe")
                }

                Menu {
                    Picker(L10n.text("appearance_section", settings.language), selection: $settings.appearance) {
                        ForEach(AppSettingsStore.Appearance.allCases) { appearance in
                            Text(appearance.title(settings.language)).tag(appearance)
                        }
                    }
                } label: {
                    drawerLabel("\(L10n.text("appearance_section", settings.language)) · \(settings.appearance.title(settings.language))", systemImage: "circle.lefthalf.filled")
                }

                drawerRow(L10n.text("settings_title", settings.language), systemImage: "gearshape") {
                    chrome.isProfileEditorPresented = true
                }
            }
            .padding(.top, 58)

            Spacer()

            Text("iumrah Project")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 24)
        .background(Color.iumrahCardBackground)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 30, topTrailingRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 30, x: 12)
        .sheet(isPresented: $chrome.isProfileEditorPresented) {
            ProfileSettingsView()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var profileCard: some View {
        Button {
            chrome.isProfileEditorPresented = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 38))
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 3) {
                    Text(settings.displayName)
                        .font(.headline)
                    Text(settings.hasBookingIdentity ? L10n.text("profile_subtitle_ready", settings.language) : L10n.text("profile_subtitle_empty", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.iumrahRaisedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func drawerRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            drawerLabel(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func drawerLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 26)
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
        .frame(height: 50)
    }
}
