import XCTest
@testable import LanguageReader

final class SentenceTranslationServiceTests: XCTestCase {
    func testFallsBackToOfflineGlossWhenConfigurationMissing() async {
        let defaults = testDefaults()
        let service = SentenceTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            cloudTranslator: FakeAzureTranslatorClient()
        )

        let translated = await service.translate(sentence: "plain unknown sentence")
        XCTAssertEqual(translated, "plain unknown sentence")
    }

    func testUsesCloudTranslatorWhenConfigured() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "germanywestcentral"
        try settings.saveAPIKey("secret")

        let fake = FakeAzureTranslatorClient(result: .success("cloud translation"))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: fake
        )

        let translated = await service.translate(sentence: "ಈ ವಾಕ್ಯ")
        XCTAssertEqual(translated, "cloud translation")
        XCTAssertEqual(fake.callCount, 1)
    }

    func testCachesRepeatedCloudTranslations() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "germanywestcentral"
        try settings.saveAPIKey("secret")

        let fake = FakeAzureTranslatorClient(result: .success("cached translation"))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: fake
        )

        let first = await service.translate(sentence: "ಈ ವಾಕ್ಯ")
        let second = await service.translate(sentence: "ಈ ವಾಕ್ಯ")

        XCTAssertEqual(first, "cached translation")
        XCTAssertEqual(second, "cached translation")
        XCTAssertEqual(fake.callCount, 1)
    }

    func testFallsBackWhenCloudTranslationFails() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "germanywestcentral"
        try settings.saveAPIKey("secret")

        let fake = FakeAzureTranslatorClient(result: .failure(FakeAzureTranslatorClient.FakeError.failed))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: fake
        )

        let translated = await service.translate(sentence: "plain unknown sentence")
        XCTAssertEqual(translated, "plain unknown sentence")
        XCTAssertEqual(fake.callCount, 1)
    }

    func testRetriesCloudAfterFailureForSameSentence() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "germanywestcentral"
        try settings.saveAPIKey("secret")

        let fake = FakeAzureTranslatorClient(
            results: [
                .failure(FakeAzureTranslatorClient.FakeError.failed),
                .success("cloud translation")
            ]
        )
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: fake
        )

        let first = await service.translate(sentence: "plain unknown sentence")
        let second = await service.translate(sentence: "plain unknown sentence")

        XCTAssertEqual(first, "plain unknown sentence")
        XCTAssertEqual(second, "cloud translation")
        XCTAssertEqual(fake.callCount, 2)
    }

    private func testDefaults() -> UserDefaults {
        let name = "SentenceTranslationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private final class FakeAzureTranslatorClient: AzureSentenceTranslating {
    enum FakeError: Error {
        case failed
    }

    private let results: [Result<String, Error>]
    private(set) var callCount = 0

    init(result: Result<String, Error> = .success("translated")) {
        self.results = [result]
    }

    init(results: [Result<String, Error>]) {
        self.results = results.isEmpty ? [.success("translated")] : results
    }

    func translate(text: String, configuration: AzureTranslatorConfiguration) async throws -> String {
        callCount += 1
        let index = min(callCount - 1, results.count - 1)
        return try results[index].get()
    }
}

private final class InMemorySecretStore: SecretStoring {
    private var values: [String: String] = [:]

    func read(account: String) -> String? {
        values[account]
    }

    func write(_ value: String, account: String) throws {
        values[account] = value
    }

    func delete(account: String) throws {
        values.removeValue(forKey: account)
    }
}
