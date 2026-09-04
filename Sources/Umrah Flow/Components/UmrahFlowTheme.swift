import SwiftUI

struct UmrahFlowPalette {
    let background: Color
    let backgroundSecondary: Color
    let textPrimary: Color
    let textSecondary: Color
    let glassTint: Color
    let glassStroke: Color
    let progressTrack: Color
    let progressStart: Color
    let progressEnd: Color
    let accent: Color
    let danger: Color

    static let dark = UmrahFlowPalette(
        background: Color(red: 0.025, green: 0.027, blue: 0.034),
        backgroundSecondary: Color(red: 0.050, green: 0.052, blue: 0.065),
        textPrimary: .white,
        textSecondary: .white.opacity(0.58),
        glassTint: .white.opacity(0.055),
        glassStroke: .white.opacity(0.14),
        progressTrack: .white.opacity(0.10),
        progressStart: Color(red: 0.56, green: 0.30, blue: 1.00),
        progressEnd: Color(red: 1.00, green: 0.46, blue: 0.10),
        accent: Color(red: 1.00, green: 0.47, blue: 0.09),
        danger: Color(red: 1.00, green: 0.27, blue: 0.23)
    )

    static let light = UmrahFlowPalette(
        background: Color(red: 0.965, green: 0.963, blue: 0.975),
        backgroundSecondary: Color(red: 0.985, green: 0.982, blue: 0.975),
        textPrimary: Color(red: 0.055, green: 0.058, blue: 0.070),
        textSecondary: Color(red: 0.055, green: 0.058, blue: 0.070).opacity(0.55),
        glassTint: .white.opacity(0.34),
        glassStroke: .black.opacity(0.075),
        progressTrack: .black.opacity(0.075),
        progressStart: Color(red: 0.52, green: 0.24, blue: 0.96),
        progressEnd: Color(red: 0.98, green: 0.40, blue: 0.06),
        accent: Color(red: 0.96, green: 0.38, blue: 0.04),
        danger: Color(red: 0.88, green: 0.18, blue: 0.17)
    )
}

struct UmrahFlowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ZStack {
            palette.background

            LinearGradient(
                colors: [
                    palette.backgroundSecondary.opacity(colorScheme == .dark ? 0.54 : 0.84),
                    palette.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [
                    (colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.025 : 0.018),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 310
            )
        }
        .ignoresSafeArea()
    }
}

enum UmrahFlowCopy {
    static func advisorSpeaking(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Advisor говорит"
        case .english: return "Advisor speaking"
        case .uzbek: return "Advisor gapiryapti"
        case .uzbekCyrillic: return "Advisor гапиряпти"
        }
    }

    static func tapToListen(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Коснитесь градиента, чтобы слушать"
        case .english: return "Tap the gradient to listen"
        case .uzbek: return "Tinglash uchun gradientga teging"
        case .uzbekCyrillic: return "Тинглаш учун градиентга тегинг"
        }
    }

    static func loadingVoice(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Загружаем голос"
        case .english: return "Loading voice"
        case .uzbek: return "Ovoz yuklanmoqda"
        case .uzbekCyrillic: return "Овоз юкланмоқда"
        }
    }

    static func tapToChange(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Коснитесь текста, чтобы изменить"
        case .english: return "Tap the text to change"
        case .uzbek: return "Matnni o‘zgartirish uchun teging"
        case .uzbekCyrillic: return "Матнни ўзгартириш учун тегинг"
        }
    }

    static func listening(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Слушать"
        case .english: return "Listening"
        case .uzbek: return "Tinglash"
        case .uzbekCyrillic: return "Тинглаш"
        }
    }

    static func reading(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Читать"
        case .english: return "Reading"
        case .uzbek: return "O‘qish"
        case .uzbekCyrillic: return "Ўқиш"
        }
    }

    static func previous(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Назад"
        case .english: return "Previous"
        case .uzbek: return "Orqaga"
        case .uzbekCyrillic: return "Орқага"
        }
    }

    static func next(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Далее"
        case .english: return "Next"
        case .uzbek: return "Keyingi"
        case .uzbekCyrillic: return "Кейинги"
        }
    }

    static func done(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Готово"
        case .english: return "Done"
        case .uzbek: return "Tayyor"
        case .uzbekCyrillic: return "Тайёр"
        }
    }


    static func guidance(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Подсказка"
        case .english: return "Guidance"
        case .uzbek: return "Yo‘riqnoma"
        case .uzbekCyrillic: return "Йўриқнома"
        }
    }

    static func dua(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Дуа"
        case .english: return "Dua"
        case .uzbek: return "Duo"
        case .uzbekCyrillic: return "Дуо"
        }
    }

    static func meaning(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Смысл"
        case .english: return "Meaning"
        case .uzbek: return "Ma’nosi"
        case .uzbekCyrillic: return "Маъноси"
        }
    }

    static func dhikr(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Зикр"
        case .english: return "Dhikr"
        case .uzbek: return "Zikr"
        case .uzbekCyrillic: return "Зикр"
        }
    }

    static func chooseStage(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Перейти к этапу"
        case .english: return "Go to a stage"
        case .uzbek: return "Bosqichga o‘tish"
        case .uzbekCyrillic: return "Босқичга ўтиш"
        }
    }

    static func leaveUmrah(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Выйти из Умры"
        case .english: return "Exit Umrah"
        case .uzbek: return "Umradan chiqish"
        case .uzbekCyrillic: return "Умрадан чиқиш"
        }
    }
}
