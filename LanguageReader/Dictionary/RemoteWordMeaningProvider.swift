import Foundation

protocol RemoteWordMeaningProviding {
    func lookupMeaning(for word: String, sourceLanguage: String, targetLanguage: String) async -> String?
}

struct AzureRemoteWordMeaningProvider: RemoteWordMeaningProviding {
    private let settingsStore: TranslationSettingsStore
    private let client: AzureSentenceTranslating

    init(
        settingsStore: TranslationSettingsStore = TranslationSettingsStore(),
        client: AzureSentenceTranslating = AzureTranslatorClient()
    ) {
        self.settingsStore = settingsStore
        self.client = client
    }

    func lookupMeaning(for word: String, sourceLanguage: String, targetLanguage: String) async -> String? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard var config = settingsStore.configuration() else {
            return nil
        }

        let source = sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !source.isEmpty, !target.isEmpty else {
            return nil
        }

        config = AzureTranslatorConfiguration(
            endpoint: config.endpoint,
            region: config.region,
            apiKey: config.apiKey,
            sourceLanguage: source,
            targetLanguage: target
        )

        do {
            let translated = try await client.translate(text: trimmed, configuration: config)
            let cleaned = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }
}
