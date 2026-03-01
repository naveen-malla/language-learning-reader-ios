import Foundation

actor SentenceTranslationService {
    static let unavailableMessage = "Sentence translation unavailable right now. Try again."

    private let settingsStore: TranslationSettingsStore
    private let cloudTranslator: AzureSentenceTranslating
    private let publicTranslator: PublicSentenceTranslating
    private let fallbackTranslator: SentenceGlossTranslator
    private var cache: [String: String] = [:]

    init(
        settingsStore: TranslationSettingsStore = TranslationSettingsStore(),
        cloudTranslator: AzureSentenceTranslating = AzureTranslatorClient(),
        publicTranslator: PublicSentenceTranslating = PublicWebTranslatorClient(),
        fallbackTranslator: SentenceGlossTranslator = SentenceGlossTranslator()
    ) {
        self.settingsStore = settingsStore
        self.cloudTranslator = cloudTranslator
        self.publicTranslator = publicTranslator
        self.fallbackTranslator = fallbackTranslator
    }

    func translate(sentence: String) async -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return sentence
        }

        let config = settingsStore.configuration()
        let sourceLanguage = normalizedLanguageCode(settingsStore.sourceLanguage) ?? TranslationSettingsStore.defaultSourceLanguage
        let targetLanguage = normalizedLanguageCode(settingsStore.targetLanguage) ?? TranslationSettingsStore.defaultTargetLanguage
        let key = cacheKey(sentence: trimmed, config: config, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        if let cached = cache[key] {
            return cached
        }

        if let config {
            if let translated = await translateWithCloudIfReadable(text: trimmed, configuration: config) {
                cache[key] = translated
                return translated
            }

            if let translated = await translateWithPublicFallback(
                text: trimmed,
                sourceLanguage: config.sourceLanguage,
                targetLanguage: config.targetLanguage
            ) {
                cache[key] = translated
                return translated
            }

            // Keep existing retry behavior on transient cloud/public failures.
            if let fallback = fallbackIfReadable(
                trimmed,
                targetLanguage: config.targetLanguage
            ) {
                return fallback
            }
            return Self.unavailableMessage
        }

        if let translated = await translateWithPublicFallback(
            text: trimmed,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            cache[key] = translated
            return translated
        }

        if let fallback = fallbackIfReadable(trimmed, targetLanguage: targetLanguage) {
            cache[key] = fallback
            return fallback
        }

        return Self.unavailableMessage
    }

    func clearCache() {
        cache.removeAll(keepingCapacity: true)
    }

    private func cacheKey(
        sentence: String,
        config: AzureTranslatorConfiguration?,
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        let prefix: String
        if let config {
            let region = config.region ?? ""
            prefix = "\(config.endpoint.absoluteString)|\(config.sourceLanguage)|\(config.targetLanguage)|\(region)"
        } else {
            prefix = "public|\(sourceLanguage)|\(targetLanguage)"
        }
        return "\(prefix)|\(sentence)"
    }

    private func translateWithCloudIfReadable(
        text: String,
        configuration: AzureTranslatorConfiguration
    ) async -> String? {
        do {
            let translated = try await cloudTranslator.translate(text: text, configuration: configuration)
            guard isReadableSentenceTranslation(
                translated,
                source: text,
                targetLanguage: configuration.targetLanguage
            ) else {
                return nil
            }
            return translated
        } catch {
            return nil
        }
    }

    private func translateWithPublicFallback(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async -> String? {
        do {
            let translated = try await publicTranslator.translate(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )

            guard isReadableSentenceTranslation(
                translated,
                source: text,
                targetLanguage: targetLanguage
            ) else {
                return nil
            }
            return translated
        } catch {
            return nil
        }
    }

    private func fallbackIfReadable(
        _ sentence: String,
        targetLanguage: String
    ) -> String? {
        let normalizedTarget = normalizedLanguageCode(targetLanguage) ?? ""
        guard normalizedTarget == "en" else {
            return nil
        }

        let fallback = fallbackTranslator.gloss(sentence)
        guard fallback.coverage >= 0.85 else {
            return nil
        }

        let text = fallback.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard isReadableSentenceTranslation(text, source: sentence, targetLanguage: targetLanguage) else {
            return nil
        }
        return text
    }

    private func isReadableSentenceTranslation(
        _ translated: String,
        source: String,
        targetLanguage: String
    ) -> Bool {
        let normalizedTarget = normalizedLanguageCode(targetLanguage) ?? ""
        let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if normalizedTarget == "en" {
            if containsKannadaScript(in: trimmed) {
                return false
            }
            if !containsLatinAlphabet(in: trimmed) {
                return false
            }
        }

        return trimmed.caseInsensitiveCompare(source.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
    }

    private func normalizedLanguageCode(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func containsKannadaScript(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0C80...0x0CFF).contains(Int(scalar.value))
        }
    }

    private func containsLatinAlphabet(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0041...0x005A).contains(Int(scalar.value)) || (0x0061...0x007A).contains(Int(scalar.value))
        }
    }
}
