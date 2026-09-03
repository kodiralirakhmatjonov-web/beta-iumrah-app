import Combine
import Foundation

@MainActor
final class UmrahFlowStore: ObservableObject {
    @Published private(set) var translations: [String: String] = [:]
    @Published private(set) var audioURLs: [String: URL] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var loadedLanguage = ""
    @Published private(set) var lastError: String?

    private let client = UmrahFlowSupabaseClient()
    private let defaults = UserDefaults.standard

    func load(language: AppSettingsStore.Language, forceRefresh: Bool = false) async {
        let code = backendLanguageCode(language)
        if !forceRefresh, loadedLanguage == code, !translations.isEmpty { return }

        loadedLanguage = code
        loadCache(language: code)
        isLoading = translations.isEmpty
        lastError = nil

        do {
            async let translationsTask = client.translations(language: code)
            async let audioTask = client.audioURLs(language: code)
            let (freshTranslations, freshAudio) = try await (translationsTask, audioTask)

            if !freshTranslations.isEmpty {
                translations = freshTranslations
                cacheTranslations(freshTranslations, language: code)
            }
            if !freshAudio.isEmpty {
                audioURLs = freshAudio
                cacheAudio(freshAudio, language: code)
            }
        } catch {
            lastError = String(describing: error)
            // Cached content remains usable. If this language has never been cached,
            // make one light English fallback attempt for the instructional text.
            if translations.isEmpty, code != "en" {
                if let fallback = try? await client.translations(language: "en"), !fallback.isEmpty {
                    translations = fallback
                }
            }
        }

        isLoading = false
    }

    func text(_ key: String, fallback: String? = nil) -> String {
        let value = translations[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !value.isEmpty { return value }
        return fallback ?? key
    }

    func audioURL(for key: String) -> URL? {
        audioURLs[key]
    }

    private func backendLanguageCode(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .uzbekCyrillic:
            // Current Supabase export contains Uzbek Latin. Keep the flow usable until
            // a dedicated uz-Cyrl pack is added to Translations 2 / audio.
            return "uz"
        default:
            return language.rawValue
        }
    }

    private func translationsCacheKey(_ language: String) -> String {
        "iumrah.umrahFlow.translations.\(language)"
    }

    private func audioCacheKey(_ language: String) -> String {
        "iumrah.umrahFlow.audio.\(language)"
    }

    private func loadCache(language: String) {
        if let data = defaults.data(forKey: translationsCacheKey(language)),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            translations = map
        } else {
            translations = [:]
        }

        if let data = defaults.data(forKey: audioCacheKey(language)),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            audioURLs = map.reduce(into: [String: URL]()) { result, entry in
                if let url = URL(string: entry.value) { result[entry.key] = url }
            }
        } else {
            audioURLs = [:]
        }
    }

    private func cacheTranslations(_ map: [String: String], language: String) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: translationsCacheKey(language))
    }

    private func cacheAudio(_ map: [String: URL], language: String) {
        let serializable = map.mapValues(\.absoluteString)
        guard let data = try? JSONEncoder().encode(serializable) else { return }
        defaults.set(data, forKey: audioCacheKey(language))
    }
}
