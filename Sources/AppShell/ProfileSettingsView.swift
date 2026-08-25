import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Профиль") {
                    TextField("Имя", text: $settings.firstName)
                        .textContentType(.givenName)
                    TextField("Фамилия", text: $settings.lastName)
                        .textContentType(.familyName)
                }

                Section("Язык") {
                    Picker("Язык приложения", selection: $settings.language) {
                        ForEach(AppSettingsStore.Language.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                }

                Section("Оформление") {
                    Picker("Тема", selection: $settings.appearance) {
                        ForEach(AppSettingsStore.Appearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
