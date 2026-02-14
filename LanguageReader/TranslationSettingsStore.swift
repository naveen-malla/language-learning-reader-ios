import Foundation

struct AzureTranslatorConfiguration {
    let endpoint: URL
    let region: String
    let apiKey: String
    let sourceLanguage: String
    let targetLanguage: String
}

struct TranslationSettingsStore {
    private enum DefaultsKeys {
        static let endpoint = "translation.azure.endpoint"
        static let region = "translation.azure.region"
        static let sourceLanguage = "translation.azure.sourceLanguage"
        static let targetLanguage = "translation.azure.targetLanguage"
    }

    private enum KeychainAccounts {
        static let apiKey = "azure-translator-api-key"
    }

    static let defaultEndpoint = "https://api.cognitive.microsofttranslator.com"
    static let defaultSourceLanguage = "kn"
    static let defaultTargetLanguage = "en"
    static let defaultRegion = ""

    private let defaults: UserDefaults
    private let keychain: any SecretStoring

    init(
        defaults: UserDefaults = .standard,
        keychain: any SecretStoring = KeychainSecretStore(service: "com.local.LanguageReader.AzureTranslator")
    ) {
        self.defaults = defaults
        self.keychain = keychain
    }

    var endpointText: String {
        get { defaults.string(forKey: DefaultsKeys.endpoint) ?? Self.defaultEndpoint }
        nonmutating set { defaults.set(normalizeEndpointText(newValue), forKey: DefaultsKeys.endpoint) }
    }

    var regionText: String {
        get { defaults.string(forKey: DefaultsKeys.region) ?? Self.defaultRegion }
        nonmutating set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKeys.region) }
    }

    var sourceLanguage: String {
        get { defaults.string(forKey: DefaultsKeys.sourceLanguage) ?? Self.defaultSourceLanguage }
        nonmutating set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKeys.sourceLanguage) }
    }

    var targetLanguage: String {
        get { defaults.string(forKey: DefaultsKeys.targetLanguage) ?? Self.defaultTargetLanguage }
        nonmutating set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKeys.targetLanguage) }
    }

    var hasAPIKey: Bool {
        guard let apiKey else { return false }
        return !apiKey.isEmpty
    }

    var apiKey: String? {
        keychain.read(account: KeychainAccounts.apiKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try keychain.write(trimmed, account: KeychainAccounts.apiKey)
    }

    func clearAPIKey() throws {
        try keychain.delete(account: KeychainAccounts.apiKey)
    }

    func clearConfiguration() {
        defaults.removeObject(forKey: DefaultsKeys.region)
        defaults.removeObject(forKey: DefaultsKeys.sourceLanguage)
        defaults.removeObject(forKey: DefaultsKeys.targetLanguage)
        defaults.removeObject(forKey: DefaultsKeys.endpoint)
    }

    func configuration() -> AzureTranslatorConfiguration? {
        guard
            let apiKey,
            !apiKey.isEmpty
        else {
            return nil
        }

        let region = regionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !region.isEmpty else {
            return nil
        }

        let endpoint = normalizeEndpointText(endpointText)
        guard let endpointURL = URL(string: endpoint) else {
            return nil
        }

        let source = sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !target.isEmpty else {
            return nil
        }

        return AzureTranslatorConfiguration(
            endpoint: endpointURL,
            region: region,
            apiKey: apiKey,
            sourceLanguage: source,
            targetLanguage: target
        )
    }

    private func normalizeEndpointText(_ endpoint: String) -> String {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") {
            return String(trimmed.dropLast())
        }
        return trimmed
    }
}
