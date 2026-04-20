import XCTest
@testable import LanguageReader

final class SentenceTranslationServiceTests: XCTestCase {
    func testWhitespaceOnlySentenceReturnsInputAndSkipsTranslators() async {
        let defaults = testDefaults()
        let cloudTranslator = FakeAzureTranslatorClient()
        let publicTranslator = FakePublicTranslator(result: .success("public translation"))
        let service = SentenceTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            cloudTranslator: cloudTranslator,
            publicTranslator: publicTranslator
        )

        let translated = await service.translate(sentence: "   \n\t")
        XCTAssertEqual(translated, "   \n\t")
        XCTAssertEqual(cloudTranslator.callCount, 0)
        XCTAssertEqual(publicTranslator.callCount, 0)
    }

    func testFallsBackToOfflineGlossWhenConfigurationMissing() async {
        let defaults = testDefaults()
        let service = SentenceTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            cloudTranslator: FakeAzureTranslatorClient(),
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
        )

        let translated = await service.translate(sentence: "plain unknown sentence")
        XCTAssertEqual(translated, SentenceTranslationService.unavailableMessage)
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
            cloudTranslator: fake,
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
        )

        let translated = await service.translate(sentence: "ಈ ವಾಕ್ಯ")
        XCTAssertEqual(translated, "cloud translation")
        XCTAssertEqual(fake.callCount, 1)
    }

    func testUsesCloudTranslatorWhenConfiguredWithoutRegion() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = " "
        try settings.saveAPIKey("secret")

        let fake = FakeAzureTranslatorClient(result: .success("cloud translation"))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: fake,
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
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
            cloudTranslator: fake,
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
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
            cloudTranslator: fake,
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
        )

        let translated = await service.translate(sentence: "plain unknown sentence")
        XCTAssertEqual(translated, SentenceTranslationService.unavailableMessage)
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
            cloudTranslator: fake,
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
        )

        let first = await service.translate(sentence: "plain unknown sentence")
        let second = await service.translate(sentence: "plain unknown sentence")

        XCTAssertEqual(first, SentenceTranslationService.unavailableMessage)
        XCTAssertEqual(second, "cloud translation")
        XCTAssertEqual(fake.callCount, 2)
    }

    func testDoesNotCacheFailuresAcrossCalls() async throws {
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
            cloudTranslator: fake,
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
        )

        let first = await service.translate(sentence: "ಪರೀಕ್ಷೆ")
        let second = await service.translate(sentence: "ಪರೀಕ್ಷೆ")

        XCTAssertNotEqual(first, "cloud translation")
        XCTAssertEqual(second, "cloud translation")
        XCTAssertEqual(fake.callCount, 2)
    }

    func testDoesNotCacheUnavailableResultWhenConfigurationMissing() async {
        let defaults = testDefaults()
        let publicTranslator = FakePublicTranslator(
            results: [
                .failure(FakePublicTranslator.FakeError.failed),
                .success("public recovery")
            ]
        )
        let service = SentenceTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            cloudTranslator: FakeAzureTranslatorClient(),
            publicTranslator: publicTranslator
        )

        let first = await service.translate(sentence: "plain unknown sentence")
        let second = await service.translate(sentence: "plain unknown sentence")

        XCTAssertEqual(first, SentenceTranslationService.unavailableMessage)
        XCTAssertEqual(second, "public recovery")
        XCTAssertEqual(publicTranslator.callCount, 2)
    }

    func testTrimmedSentenceIsUsedForCacheKey() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "germanywestcentral"
        try settings.saveAPIKey("secret")

        let fake = FakeAzureTranslatorClient(results: [.success("one"), .success("two")])
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: fake,
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
        )

        let first = await service.translate(sentence: "  ಪದ ")
        let second = await service.translate(sentence: "ಪದ")

        XCTAssertEqual(first, "one")
        XCTAssertEqual(second, "one")
        XCTAssertEqual(fake.callCount, 1)
    }

    func testCacheKeyIncludesLanguagePairWhenConfigurationMissing() async {
        let defaults = testDefaults()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore())
        settings.sourceLanguage = "kn"
        settings.targetLanguage = "en"

        let publicTranslator = FakePublicTranslator(results: [
            .success("english translation"),
            .success("hindi translation")
        ])
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: FakeAzureTranslatorClient(),
            publicTranslator: publicTranslator
        )

        let english = await service.translate(sentence: "ಇದು ಪರೀಕ್ಷೆ")
        settings.targetLanguage = "hi"
        let hindi = await service.translate(sentence: "ಇದು ಪರೀಕ್ಷೆ")

        XCTAssertEqual(english, "english translation")
        XCTAssertEqual(hindi, "hindi translation")
        XCTAssertEqual(publicTranslator.callCount, 2)
    }

    func testUsesPublicTranslatorWhenConfigurationMissing() async {
        let defaults = testDefaults()
        let publicTranslator = FakePublicTranslator(result: .success("public translation"))
        let service = SentenceTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            cloudTranslator: FakeAzureTranslatorClient(),
            publicTranslator: publicTranslator
        )

        let translated = await service.translate(sentence: "ಇದು ಪರೀಕ್ಷೆ")
        XCTAssertEqual(translated, "public translation")
        XCTAssertEqual(publicTranslator.callCount, 1)
    }

    func testUsesPublicTranslatorWhenCloudFails() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "eastus"
        try settings.saveAPIKey("secret")

        let publicTranslator = FakePublicTranslator(result: .success("public translation"))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: FakeAzureTranslatorClient(result: .failure(FakeAzureTranslatorClient.FakeError.failed)),
            publicTranslator: publicTranslator
        )

        let translated = await service.translate(sentence: "ಇದು ಪರೀಕ್ಷೆ")
        XCTAssertEqual(translated, "public translation")
        XCTAssertEqual(publicTranslator.callCount, 1)
    }

    func testRejectsUnreadableCloudOutputAndFallsBackToPublic() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "eastus"
        try settings.saveAPIKey("secret")

        let publicTranslator = FakePublicTranslator(result: .success("clean public translation"))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: FakeAzureTranslatorClient(result: .success("a raised lining ಭಾರತೀಯರ")),
            publicTranslator: publicTranslator
        )

        let translated = await service.translate(sentence: "ಉತ್ತರ ಭಾರತೀಯರ ಮೇಲಿನ")
        XCTAssertEqual(translated, "clean public translation")
        XCTAssertEqual(publicTranslator.callCount, 1)
    }

    func testRejectsUnchangedGermanCloudOutputAndFallsBackToPublic() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "germanywestcentral"
        try settings.saveAPIKey("secret")

        let publicTranslator = FakePublicTranslator(result: .success("This is my house."))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: FakeAzureTranslatorClient(result: .success("Das ist mein Haus.")),
            publicTranslator: publicTranslator
        )

        let translated = await service.translate(
            sentence: "Das ist mein Haus.",
            sourceLanguage: "de-DE",
            targetLanguage: "en-US"
        )

        XCTAssertEqual(translated, "This is my house.")
        XCTAssertEqual(publicTranslator.callCount, 1)
    }

    func testRejectsUnreadableCloudPublicAndFallbackOutput() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "eastus"
        try settings.saveAPIKey("secret")

        let manager = makeDictionaryManager(entries: ["ಉತ್ತರ": "a raised lining running at a height all round the inside of walls in buildings"])
        let fallbackTranslator = SentenceGlossTranslator(dictionaryManager: manager)
        let publicTranslator = FakePublicTranslator(result: .success("ಉತ್ತರ ಬಹಳ ದೊಡ್ಡ ಅರ್ಥ"))
        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: FakeAzureTranslatorClient(result: .success("a raised lining ಭಾರತೀಯರ")),
            publicTranslator: publicTranslator,
            fallbackTranslator: fallbackTranslator
        )

        let translated = await service.translate(sentence: "ಉತ್ತರ ಭಾರತೀಯರ ಮೇಲಿನ")
        XCTAssertEqual(translated, SentenceTranslationService.unavailableMessage)
    }

    func testRejectsUnreadablePublicAndFallbackOutput() async {
        let defaults = testDefaults()
        let manager = makeDictionaryManager(entries: ["ಉತ್ತರ": "a raised lining running at a height all round the inside of walls in buildings"])
        let fallbackTranslator = SentenceGlossTranslator(dictionaryManager: manager)
        let publicTranslator = FakePublicTranslator(result: .success("ಉತ್ತರ ಬಹಳ ದೊಡ್ಡ ಅರ್ಥ"))

        let service = SentenceTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            cloudTranslator: FakeAzureTranslatorClient(),
            publicTranslator: publicTranslator,
            fallbackTranslator: fallbackTranslator
        )

        let translated = await service.translate(sentence: "ಉತ್ತರ ಭಾರತೀಯರ ಮೇಲಿನ")
        XCTAssertEqual(translated, SentenceTranslationService.unavailableMessage)
    }

    func testUsesReadableFallbackGlossWhenCoverageIsHigh() async {
        let defaults = testDefaults()
        let manager = makeDictionaryManager(entries: ["ಇದು": "this", "ಮನೆ": "house", "ಚೆನ್ನಾಗಿದೆ": "is good"])
        let fallbackTranslator = SentenceGlossTranslator(dictionaryManager: manager)

        let service = SentenceTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            cloudTranslator: FakeAzureTranslatorClient(),
            publicTranslator: FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed)),
            fallbackTranslator: fallbackTranslator
        )

        let translated = await service.translate(sentence: "ಇದು ಮನೆ ಚೆನ್ನಾಗಿದೆ")
        XCTAssertEqual(translated, "this house is good")
    }

    func testConfiguredFallbackIsNotCachedSoCloudCanRecover() async throws {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "germanywestcentral"
        try settings.saveAPIKey("secret")

        let cloudTranslator = FakeAzureTranslatorClient(
            results: [
                .failure(FakeAzureTranslatorClient.FakeError.failed),
                .success("cloud translation")
            ]
        )
        let publicTranslator = FakePublicTranslator(result: .failure(FakePublicTranslator.FakeError.failed))
        let manager = makeDictionaryManager(entries: ["ಇದು": "this", "ಮನೆ": "house", "ಚೆನ್ನಾಗಿದೆ": "is good"])
        let fallbackTranslator = SentenceGlossTranslator(dictionaryManager: manager)

        let service = SentenceTranslationService(
            settingsStore: settings,
            cloudTranslator: cloudTranslator,
            publicTranslator: publicTranslator,
            fallbackTranslator: fallbackTranslator
        )

        let first = await service.translate(sentence: "ಇದು ಮನೆ ಚೆನ್ನಾಗಿದೆ")
        let second = await service.translate(sentence: "ಇದು ಮನೆ ಚೆನ್ನಾಗಿದೆ")

        XCTAssertEqual(first, "this house is good")
        XCTAssertEqual(second, "cloud translation")
        XCTAssertEqual(cloudTranslator.callCount, 2)
        XCTAssertEqual(publicTranslator.callCount, 1)
    }

    private func testDefaults() -> UserDefaults {
        let name = "SentenceTranslationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeDictionaryManager(entries: [String: String]) -> DictionaryManager {
        DictionaryManager(
            provider: TestDictionaryProvider(entries: entries),
            overrideStore: DictionaryOverrideStore(
                fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-overrides.tsv"),
                missingURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-missing.tsv")
            ),
            cloudStore: DictionaryCloudMeaningStore(fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-cloud.tsv")),
            remoteProvider: nil,
            sourceLanguageProvider: { "kn" },
            targetLanguageProvider: { "en" }
        )
    }
}

private struct TestDictionaryProvider: DictionaryProvider {
    let entries: [String: String]

    func lookup(normalizedKey: String) -> String? {
        entries[normalizedKey]
    }

    var sourceDescription: String {
        "test"
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

private final class FakePublicTranslator: PublicSentenceTranslating {
    enum FakeError: Error {
        case failed
    }

    private let results: [Result<String, Error>]
    private(set) var callCount = 0

    init(result: Result<String, Error>) {
        self.results = [result]
    }

    init(results: [Result<String, Error>]) {
        self.results = results.isEmpty ? [.failure(FakeError.failed)] : results
    }

    func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String {
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
