import Foundation

actor SentenceTranslationService {
    private let settingsStore: TranslationSettingsStore
    private let cloudTranslator: AzureSentenceTranslating
    private let fallbackTranslator: SentenceGlossTranslator
    private var cache: [String: String] = [:]

    init(
        settingsStore: TranslationSettingsStore = TranslationSettingsStore(),
        cloudTranslator: AzureSentenceTranslating = AzureTranslatorClient(),
        fallbackTranslator: SentenceGlossTranslator = SentenceGlossTranslator()
    ) {
        self.settingsStore = settingsStore
        self.cloudTranslator = cloudTranslator
        self.fallbackTranslator = fallbackTranslator
    }

    func translate(sentence: String) async -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return sentence
        }

        let config = settingsStore.configuration()
        let key = cacheKey(sentence: trimmed, config: config)
        if let cached = cache[key] {
            return cached
        }

        if let config {
            do {
                let translated = try await cloudTranslator.translate(text: trimmed, configuration: config)
                cache[key] = translated
                return translated
            } catch {
                // Keep the existing offline behavior when API config/network fails.
                let fallback = fallbackTranslator.gloss(trimmed).text
                cache[key] = fallback
                return fallback
            }
        }

        let fallback = fallbackTranslator.gloss(trimmed).text
        cache[key] = fallback
        return fallback
    }

    func clearCache() {
        cache.removeAll(keepingCapacity: true)
    }

    private func cacheKey(sentence: String, config: AzureTranslatorConfiguration?) -> String {
        let prefix: String
        if let config {
            prefix = "\(config.endpoint.absoluteString)|\(config.sourceLanguage)|\(config.targetLanguage)|\(config.region)"
        } else {
            prefix = "offline"
        }
        return "\(prefix)|\(sentence)"
    }
}
