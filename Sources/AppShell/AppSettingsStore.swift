import SwiftUI

final class AppSettingsStore: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return "Как на iPhone"
            case .light: return "Светлая"
            case .dark: return "Тёмная"
            }
        }
    }

    enum Language: String, CaseIterable, Identifiable {
        case russian = "ru"
        case english = "en"
        case uzbek = "uz"

        var id: String { rawValue }
        var title: String {
            switch self {
            case .russian: return "Русский"
            case .english: return "English"
            case .uzbek: return "O‘zbek"
            }
        }
    }

    @Published var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "iumrah.appearance") }
    }
    @Published var language: Language {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "iumrah.language") }
    }
    @Published var firstName: String {
        didSet { UserDefaults.standard.set(firstName, forKey: "iumrah.firstName") }
    }
    @Published var lastName: String {
        didSet { UserDefaults.standard.set(lastName, forKey: "iumrah.lastName") }
    }

    init() {
        let defaults = UserDefaults.standard
        appearance = Appearance(rawValue: defaults.string(forKey: "iumrah.appearance") ?? "system") ?? .system
        language = Language(rawValue: defaults.string(forKey: "iumrah.language") ?? "ru") ?? .russian
        firstName = defaults.string(forKey: "iumrah.firstName") ?? ""
        lastName = defaults.string(forKey: "iumrah.lastName") ?? ""
    }

    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        let value = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return value.isEmpty ? "Ваш профиль" : value
    }
}
