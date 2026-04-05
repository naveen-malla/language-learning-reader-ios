import Foundation
import XCTest
@testable import LanguageReader

final class RemoteWordMeaningProviderTests: XCTestCase {
    func testLookupMeaningReturnsNilForBlankWordWithoutCallingClient() async {
        let defaults = UserDefaults(suiteName: "RemoteWordMeaningProviderTests.\(UUID().uuidString)")!
        let keychain = InMemoryRemoteSecretStore(seed: ["azure-translator-api-key": "secret"])
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        let client = CapturingAzureSentenceTranslator()
        let provider = AzureRemoteWordMeaningProvider(settingsStore: settings, client: client)

        let result = await provider.lookupMeaning(
            for: "   ",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        XCTAssertNil(result)
        let calls = await client.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testLookupMeaningReturnsNilWhenConfigurationMissing() async {
        let defaults = UserDefaults(suiteName: "RemoteWordMeaningProviderTests.\(UUID().uuidString)")!
        let settings = TranslationSettingsStore(defaults: defaults, keychain: InMemoryRemoteSecretStore())
        let client = CapturingAzureSentenceTranslator()
        let provider = AzureRemoteWordMeaningProvider(settingsStore: settings, client: client)

        let result = await provider.lookupMeaning(
            for: "ಪದ",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        XCTAssertNil(result)
        let calls = await client.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testLookupMeaningNormalizesLanguagesAndTrimsTranslatedValue() async {
        let defaults = UserDefaults(suiteName: "RemoteWordMeaningProviderTests.\(UUID().uuidString)")!
        let keychain = InMemoryRemoteSecretStore(seed: ["azure-translator-api-key": "secret"])
        var settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.endpointText = " https://api.cognitive.microsofttranslator.com/ "
        settings.regionText = " eastus "
        settings.sourceLanguage = "kn"
        settings.targetLanguage = "en"

        let client = CapturingAzureSentenceTranslator(result: .success("  meaning  "))
        let provider = AzureRemoteWordMeaningProvider(settingsStore: settings, client: client)

        let result = await provider.lookupMeaning(
            for: "  ಪದ  ",
            sourceLanguage: " KN ",
            targetLanguage: " EN "
        )

        XCTAssertEqual(result, "meaning")
        let calls = await client.recordedCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].text, "ಪದ")
        XCTAssertEqual(calls[0].configuration.sourceLanguage, "kn")
        XCTAssertEqual(calls[0].configuration.targetLanguage, "en")
        XCTAssertEqual(calls[0].configuration.region, "eastus")
        XCTAssertEqual(
            calls[0].configuration.endpoint.absoluteString,
            "https://api.cognitive.microsofttranslator.com"
        )
        XCTAssertEqual(calls[0].configuration.apiKey, "secret")
    }

    func testLookupMeaningReturnsNilForEmptyTranslatedValue() async {
        let defaults = UserDefaults(suiteName: "RemoteWordMeaningProviderTests.\(UUID().uuidString)")!
        let keychain = InMemoryRemoteSecretStore(seed: ["azure-translator-api-key": "secret"])
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        let client = CapturingAzureSentenceTranslator(result: .success("   "))
        let provider = AzureRemoteWordMeaningProvider(settingsStore: settings, client: client)

        let result = await provider.lookupMeaning(
            for: "ಪದ",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        XCTAssertNil(result)
    }

    func testLookupMeaningReturnsNilWhenClientThrows() async {
        let defaults = UserDefaults(suiteName: "RemoteWordMeaningProviderTests.\(UUID().uuidString)")!
        let keychain = InMemoryRemoteSecretStore(seed: ["azure-translator-api-key": "secret"])
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        let client = CapturingAzureSentenceTranslator(result: .failure(URLError(.cannotConnectToHost)))
        let provider = AzureRemoteWordMeaningProvider(settingsStore: settings, client: client)

        let result = await provider.lookupMeaning(
            for: "ಪದ",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        XCTAssertNil(result)
    }
}

private final class InMemoryRemoteSecretStore: SecretStoring {
    private var values: [String: String]

    init(seed: [String: String] = [:]) {
        self.values = seed
    }

    func write(_ value: String, account: String) throws {
        values[account] = value
    }

    func read(account: String) -> String? {
        values[account]
    }

    func delete(account: String) throws {
        values.removeValue(forKey: account)
    }
}

private actor CapturingAzureSentenceTranslator: AzureSentenceTranslating {
    struct Call {
        let text: String
        let configuration: AzureTranslatorConfiguration
    }

    private var calls: [Call] = []
    private let result: Result<String, Error>

    init(result: Result<String, Error> = .success("translated")) {
        self.result = result
    }

    func translate(text: String, configuration: AzureTranslatorConfiguration) async throws -> String {
        calls.append(Call(text: text, configuration: configuration))
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    func recordedCalls() -> [Call] {
        calls
    }
}
