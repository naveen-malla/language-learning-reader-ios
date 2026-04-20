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

    func translate(
        sentence: String,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil
    ) async -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return sentence
        }

        let config = settingsStore.configuration()
        let resolvedSourceLanguage = normalizedLanguageCode(sourceLanguage)
            ?? normalizedLanguageCode(settingsStore.sourceLanguage)
            ?? TranslationSettingsStore.defaultSourceLanguage
        let resolvedTargetLanguage = normalizedLanguageCode(targetLanguage)
            ?? normalizedLanguageCode(settingsStore.targetLanguage)
            ?? TranslationSettingsStore.defaultTargetLanguage
        let key = cacheKey(
            sentence: trimmed,
            config: config,
            sourceLanguage: resolvedSourceLanguage,
            targetLanguage: resolvedTargetLanguage
        )
        if let cached = cache[key] {
            return cached
        }

        if let config {
            let effectiveConfig = AzureTranslatorConfiguration(
                endpoint: config.endpoint,
                region: config.region,
                apiKey: config.apiKey,
                sourceLanguage: resolvedSourceLanguage,
                targetLanguage: resolvedTargetLanguage
            )
            if let translated = await translateWithCloudIfReadable(text: trimmed, configuration: effectiveConfig) {
                cache[key] = translated
                return translated
            }

            if let translated = await translateWithPublicFallback(
                text: trimmed,
                sourceLanguage: effectiveConfig.sourceLanguage,
                targetLanguage: effectiveConfig.targetLanguage
            ) {
                cache[key] = translated
                return translated
            }

            // Keep existing retry behavior on transient cloud/public failures.
            if let fallback = fallbackIfReadable(
                trimmed,
                targetLanguage: effectiveConfig.targetLanguage,
                sourceLanguage: effectiveConfig.sourceLanguage
            ) {
                return fallback
            }
            return Self.unavailableMessage
        }

        if let translated = await translateWithPublicFallback(
            text: trimmed,
            sourceLanguage: resolvedSourceLanguage,
            targetLanguage: resolvedTargetLanguage
        ) {
            cache[key] = translated
            return translated
        }

        if let fallback = fallbackIfReadable(
            trimmed,
            targetLanguage: resolvedTargetLanguage,
            sourceLanguage: resolvedSourceLanguage
        ) {
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
            prefix = "\(config.endpoint.absoluteString)|\(sourceLanguage)|\(targetLanguage)|\(region)"
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
                sourceLanguage: configuration.sourceLanguage,
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
                sourceLanguage: sourceLanguage,
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
        targetLanguage: String,
        sourceLanguage: String
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
        guard isReadableSentenceTranslation(
            text,
            source: sentence,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) else {
            return nil
        }
        return text
    }

    private func isReadableSentenceTranslation(
        _ translated: String,
        source: String,
        sourceLanguage: String? = nil,
        targetLanguage: String
    ) -> Bool {
        let normalizedTarget = normalizedLanguageCode(targetLanguage) ?? ""
        let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if normalizedTarget == "en" {
            return LanguageTextHeuristics.isReadableEnglishTranslation(
                trimmed,
                source: source,
                sourceLanguage: sourceLanguage
            )
        }

        return trimmed.caseInsensitiveCompare(source.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
    }

    private func normalizedLanguageCode(_ value: String?) -> String? {
        let canonical = LanguageTextHeuristics.canonicalLanguageCode(value)
        return canonical.isEmpty ? nil : canonical
    }
}
