import Combine
import Foundation

@MainActor
final class UmrahFlowStore: ObservableObject {
    @Published private(set) var translations: [String: String] = [:]
    @Published private(set) var audioURLs: [String: URL] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var loadedLanguage = ""
    @Published private(set) var lastError: String?
    @Published private(set) var guideLanguage: UmrahGuideLanguage

    private let client = UmrahFlowSupabaseClient()
    private let defaults = UserDefaults.standard

    init(language: UmrahGuideLanguage = .english) {
        guideLanguage = language
    }

    func load(forceRefresh: Bool = false) async {
        await load(language: guideLanguage, forceRefresh: forceRefresh)
    }

    func load(language: UmrahGuideLanguage, forceRefresh: Bool = false) async {
        guideLanguage = language
        let code = language.rawValue
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
        }

        // Keep every selected guide language usable even when one layer has not
        // yet been published in Supabase. Religious copy is never fabricated:
        // English is used only as a text fallback when the requested language
        // contains no Umrah Flow translation rows at all.
        if translations.isEmpty, code != UmrahGuideLanguage.english.rawValue {
            if let fallback = try? await client.translations(language: UmrahGuideLanguage.english.rawValue),
               !fallback.isEmpty {
                translations = fallback
            }
        }

        isLoading = false
    }

    // Compatibility for any older call site that still passes the app language.
    func load(language: AppSettingsStore.Language, forceRefresh: Bool = false) async {
        await load(language: UmrahGuideLanguage.preferred(for: language), forceRefresh: forceRefresh)
    }

    func text(_ key: String, fallback: String? = nil) -> String {
        let value = translations[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !value.isEmpty { return value }
        return fallback ?? key
    }

    func audioURL(for key: String) -> URL? {
        audioURLs[key]
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
