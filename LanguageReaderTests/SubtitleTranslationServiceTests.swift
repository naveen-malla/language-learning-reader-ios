import XCTest
@testable import LanguageReader

final class SubtitleTranslationServiceTests: XCTestCase {
    func testUsesCachedTranslationsWhenCompatible() async throws {
        let sourceCues = makeSourceCues()
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.1, translatedText: "First"),
            TranslatedSubtitleCue(startTime: 1.4, duration: 1.0, translatedText: "Second")
        ]
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [.success(["unused"])])
        )

        let result = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: cachedCues)

        XCTAssertEqual(result, .cached(cachedCues))
    }

    func testTranslatesThenReusesCacheOnNextCall() async throws {
        let sourceCues = makeSourceCues()
        let translator = FakeAzureSubtitleCueTranslator(results: [
            .success(["First", "Second"])
        ])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        let first = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: nil)
        guard case .translated(let translatedCues) = first else {
            return XCTFail("Expected translated cues on first call")
        }

        let second = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: translatedCues)

        XCTAssertEqual(second, .cached(translatedCues))
        let callCount = await translator.getCallCount()
        XCTAssertEqual(callCount, 1)
    }

    func testReturnsConfigurationMessageWhenAzureIsMissing() async {
        let defaults = testDefaults()
        let service = SubtitleTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            translator: FakeAzureSubtitleCueTranslator(results: [.success(["First", "Second"])])
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        XCTAssertEqual(result, .unavailable(SubtitleTranslationService.needsConfigurationMessage))
    }

    func testReturnsUnavailableMessageWhenSourceCuesAreEmpty() async {
        let translator = FakeAzureSubtitleCueTranslator(results: [.success(["unused"])])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        let result = await service.translateIfNeeded(sourceCues: [], cachedCues: nil)

        XCTAssertEqual(result, .unavailable(SubtitleTranslationService.unavailableMessage))
        let callCount = await translator.getCallCount()
        XCTAssertEqual(callCount, 0)
    }

    func testReturnsRequestFailureMessageWhenTranslatorFails() async throws {
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [.failure(FakeAzureSubtitleCueTranslator.FakeError.failed)])
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        XCTAssertEqual(result, .unavailable(SubtitleTranslationService.requestFailedMessage))
    }

    func testReturnsRejectedOutputMessageWhenAzureReturnsUnusableEnglish() async throws {
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [
                .success([
                    "ಮೊದಲ ಸಾಲು",
                    "ಎರಡನೇ ಸಾಲು"
                ])
            ])
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        XCTAssertEqual(result, .unavailable(SubtitleTranslationService.rejectedOutputMessage))
    }

    func testCachedTranslationsAreStillReusedAfterTransientFailure() async throws {
        let sourceCues = makeSourceCues()
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.1, translatedText: "First"),
            TranslatedSubtitleCue(startTime: 1.4, duration: 1.0, translatedText: "Second")
        ]
        let translator = FakeAzureSubtitleCueTranslator(results: [
            .failure(FakeAzureSubtitleCueTranslator.FakeError.failed),
            .success(["First", "Second"])
        ])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        let first = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: nil)
        XCTAssertEqual(first, .unavailable(SubtitleTranslationService.requestFailedMessage))

        let second = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: cachedCues)

        XCTAssertEqual(second, .cached(cachedCues))
        let callCount = await translator.getCallCount()
        XCTAssertEqual(callCount, 1)
    }

    func testReturnsRequestFailureMessageWhenTranslatorReturnsWrongCueCount() async throws {
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [
                .success(["Only one line"])
            ])
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        XCTAssertEqual(result, .unavailable(SubtitleTranslationService.requestFailedMessage))
    }

    private func configuredSettings() -> TranslationSettingsStore {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "eastus"
        try! settings.saveAPIKey("secret")
        return settings
    }

    private func makeSourceCues() -> [TimedSubtitleCue] {
        [
            TimedSubtitleCue(startTime: 0, duration: 1.1, sourceText: "ಮೊದಲ ಸಾಲು"),
            TimedSubtitleCue(startTime: 1.4, duration: 1.0, sourceText: "ಎರಡನೇ ಸಾಲು")
        ]
    }

    private func testDefaults() -> UserDefaults {
        let name = "SubtitleTranslationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private actor FakeAzureSubtitleCueTranslator: AzureSubtitleCueTranslating {
    enum FakeError: Error {
        case failed
    }

    private let results: [Result<[String], Error>]
    private var callCount = 0

    init(results: [Result<[String], Error>]) {
        self.results = results.isEmpty ? [.success([])] : results
    }

    func translate(texts: [String], configuration: AzureTranslatorConfiguration) async throws -> [String] {
        callCount += 1
        let index = min(callCount - 1, results.count - 1)
        return try results[index].get()
    }

    func getCallCount() -> Int {
        callCount
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
