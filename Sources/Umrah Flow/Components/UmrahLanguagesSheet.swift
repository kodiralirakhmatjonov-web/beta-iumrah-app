import SwiftUI

struct UmrahLanguagesSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    private let languages = [
        "Русский", "English", "O‘zbek", "Қазақша", "Bahasa Indonesia",
        "Türkçe", "العربية", "Bahasa Melayu", "বাংলা", "Français"
    ]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(copy.title, systemImage: "globe")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(copy.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UmrahGlassIconButton(systemName: "xmark", foreground: .primary, accessibilityLabel: "Close") {
                    dismiss()
                }
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(languages, id: \.self) { language in
                        Text(language)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.primary.opacity(0.022), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
        .padding(22)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(.thinMaterial)
    }

    private var copy: (title: String, subtitle: String) {
        switch settings.language {
        case .russian: return ("10+ языков", "Голосовой гид iumrah Advisor доступен на разных языках.")
        case .english: return ("10+ languages", "iumrah Advisor voice guidance is available in multiple languages.")
        case .uzbek: return ("10+ til", "iumrah Advisor ovozli gidi bir nechta tillarda mavjud.")
        case .uzbekCyrillic: return ("10+ тил", "iumrah Advisor овозли гиди бир нечта тилларда мавжуд.")
        }
    }
}
