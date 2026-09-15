import SwiftUI

struct IumrahLanguageSelectionSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    private struct LanguageOption: Identifiable {
        let id: String
        let nativeName: String
        let subtitle: String
        let flag: String
        let selectableLanguage: AppSettingsStore.Language?
    }

    private var availableLanguages: [LanguageOption] {
        [
            LanguageOption(id: "en", nativeName: "English", subtitle: "English", flag: "EN", selectableLanguage: .english),
            LanguageOption(id: "ru", nativeName: "Русский", subtitle: "Russian", flag: "RU", selectableLanguage: .russian),
            LanguageOption(id: "uz", nativeName: "O‘zbekcha", subtitle: "Uzbek · Latin", flag: "UZ", selectableLanguage: .uzbek),
            LanguageOption(id: "uz-Cyrl", nativeName: "Ўзбекча", subtitle: "Uzbek · Cyrillic", flag: "ЎЗ", selectableLanguage: .uzbekCyrillic)
        ]
    }

    private var comingSoonLanguages: [LanguageOption] {
        [
            LanguageOption(id: "ar", nativeName: "العربية", subtitle: "Arabic", flag: "AR", selectableLanguage: nil),
            LanguageOption(id: "fr", nativeName: "Français", subtitle: "French", flag: "FR", selectableLanguage: nil),
            LanguageOption(id: "tr", nativeName: "Türkçe", subtitle: "Turkish", flag: "TR", selectableLanguage: nil),
            LanguageOption(id: "id", nativeName: "Bahasa Indonesia", subtitle: "Indonesian", flag: "ID", selectableLanguage: nil),
            LanguageOption(id: "ms", nativeName: "Bahasa Melayu", subtitle: "Malay", flag: "MS", selectableLanguage: nil),
            LanguageOption(id: "kk", nativeName: "Қазақша", subtitle: "Kazakh", flag: "KZ", selectableLanguage: nil),
            LanguageOption(id: "bn", nativeName: "বাংলা", subtitle: "Bengali", flag: "BN", selectableLanguage: nil)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(title)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .tracking(-0.65)
                        Text(subtitle)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    languageGroup(title: availableTitle, options: availableLanguages, enabled: true)
                    languageGroup(title: comingSoonTitle, options: comingSoonLanguages, enabled: false)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .iumrahGlass(in: Circle(), interactive: true, chrome: true)
                    .accessibilityLabel(closeTitle)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }

    private func languageGroup(title: String, options: [LanguageOption], enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 9) {
                ForEach(options) { option in
                    languageRow(option, enabled: enabled)
                }
            }
        }
    }

    private func languageRow(_ option: LanguageOption, enabled: Bool) -> some View {
        Button {
            guard let language = option.selectableLanguage else { return }
            settings.language = language
            IumrahHaptics.selection()
            dismiss()
        } label: {
            HStack(spacing: 13) {
                Text(option.flag)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(enabled ? Color.primary : Color.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.nativeName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(enabled ? Color.primary : Color.secondary)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if let language = option.selectableLanguage {
                    if settings.language == language {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.primary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(soonTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.primary.opacity(0.055), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                interactive: enabled,
                chrome: enabled
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var title: String {
        switch settings.language {
        case .russian: return "Язык iumrah"
        case .english: return "iumrah language"
        case .uzbek: return "iumrah tili"
        case .uzbekCyrillic: return "iumrah тили"
        }
    }

    private var subtitle: String {
        switch settings.language {
        case .russian: return "Выберите язык приложения. Остальные языки уже в списке развития и будут открываться по мере готовности."
        case .english: return "Choose the app language. More languages are already on the roadmap and will unlock as they become ready."
        case .uzbek: return "Ilova tilini tanlang. Qolgan tillar rivojlanish rejasida va tayyor bo‘lgani sari ochiladi."
        case .uzbekCyrillic: return "Илова тилини танланг. Қолган тиллар ривожланиш режасида ва тайёр бўлгани сари очилади."
        }
    }

    private var availableTitle: String {
        switch settings.language {
        case .russian: return "Доступно сейчас"
        case .english: return "Available now"
        case .uzbek: return "Hozir mavjud"
        case .uzbekCyrillic: return "Ҳозир мавжуд"
        }
    }

    private var comingSoonTitle: String {
        switch settings.language {
        case .russian: return "Следующие языки"
        case .english: return "Coming next"
        case .uzbek: return "Keyingi tillar"
        case .uzbekCyrillic: return "Кейинги тиллар"
        }
    }

    private var soonTitle: String {
        switch settings.language {
        case .russian: return "СКОРО"
        case .english: return "SOON"
        case .uzbek: return "TEZ ORADA"
        case .uzbekCyrillic: return "ТЕЗ ОРАДА"
        }
    }

    private var closeTitle: String {
        switch settings.language {
        case .russian: return "Закрыть"
        case .english: return "Close"
        case .uzbek: return "Yopish"
        case .uzbekCyrillic: return "Ёпиш"
        }
    }
}
