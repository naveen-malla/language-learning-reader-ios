import XCTest
@testable import LanguageReader

final class DictionaryManagerTests: XCTestCase {
    private var cleanupURLs: [URL] = []
    private var cleanupDefaultsSuites: [String] = []

    override func tearDown() {
        let fileManager = FileManager.default
        for url in cleanupURLs {
            try? fileManager.removeItem(at: url)
        }
        cleanupURLs.removeAll()

        for suite in cleanupDefaultsSuites {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        cleanupDefaultsSuites.removeAll()
        super.tearDown()
    }

    private func makeManager(
        entries: [String: String],
        overrides: [String: String] = [:],
        missingURL: URL? = nil,
        cloudEntries: [CachedWordMeaning] = [],
        remoteProvider: RemoteWordMeaningProviding? = nil,
        sourceLanguage: String = "kn",
        targetLanguage: String = "en",
        cloudFallbackEnabled: Bool = true,
        cloudFallbackTargetLanguageOverride: String? = nil
    ) -> DictionaryManager {
        let provider = SampleDictionaryProvider(entries: entries)
        let overrideStore = DictionaryOverrideStore(
            fileURL: nil,
            missingURL: missingURL,
            overrides: overrides
        )
        let cloudStore = DictionaryCloudMeaningStore(fileURL: nil, entries: cloudEntries)
        let suite = "DictionaryManagerTests.\(UUID().uuidString)"
        cleanupDefaultsSuites.append(suite)
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(cloudFallbackEnabled, forKey: DictionaryManager.cloudFallbackEnabledKey)
        if let cloudFallbackTargetLanguageOverride {
            defaults.set(cloudFallbackTargetLanguageOverride, forKey: DictionaryManager.cloudFallbackTargetLanguageKey)
        }

        return DictionaryManager(
            provider: provider,
            overrideStore: overrideStore,
            cloudStore: cloudStore,
            remoteProvider: remoteProvider,
            sourceLanguageProvider: { sourceLanguage },
            targetLanguageProvider: { targetLanguage },
            defaults: defaults
        )
    }

    private func makeTemporaryURL(fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cleanupURLs.append(directory)
        return directory.appendingPathComponent(fileName)
    }

    func testLookupWithWhitespaceAndCaseNormalization() {
        let manager = makeManager(entries: ["hello": "hi"])

        XCTAssertEqual(manager.lookup("HELLO"), "hi")
        XCTAssertEqual(manager.lookup("HeLLo"), "hi")
        XCTAssertEqual(manager.lookup("  hello  "), "hi")
        XCTAssertEqual(manager.lookup("\nhello\t"), "hi")
    }

    func testLookupDetailedDirectPath() {
        let manager = makeManager(entries: ["ಮನೆ": "house"])
        let result = manager.lookupDetailed("ಮನೆ")

        XCTAssertEqual(result.path, .direct)
        XCTAssertEqual(result.matchedKey, "ಮನೆ")
        XCTAssertEqual(result.meaning, "house")
    }

    func testLookupDetailedSuffixPathForInflectedKannadaForm() {
        let manager = makeManager(entries: ["ಮನೆ": "house"])
        let result = manager.lookupDetailed("ಮನೆಯಲಿ")

        XCTAssertEqual(result.path, .suffix)
        XCTAssertEqual(result.matchedKey, "ಮನೆ")
        XCTAssertEqual(result.meaning, "house")
    }

    func testLookupDetailedSuffixPathForAccusativeForm() {
        let manager = makeManager(entries: ["ಪದ": "word"])
        let result = manager.lookupDetailed("ಪದವನ್ನು")

        XCTAssertEqual(result.path, .suffix)
        XCTAssertEqual(result.matchedKey, "ಪದ")
        XCTAssertEqual(result.meaning, "word")
    }

    func testLookupDetailedSuffixPathForGenitiveForm() {
        let manager = makeManager(entries: ["ಮನೆ": "house"])
        let result = manager.lookupDetailed("ಮನೆಯ")

        XCTAssertEqual(result.path, .suffix)
        XCTAssertEqual(result.matchedKey, "ಮನೆ")
        XCTAssertEqual(result.meaning, "house")
    }

    func testLookupDetailedSuffixPathForVerbProgressiveForm() {
        let manager = makeManager(entries: ["ಬೀಸು": "to blow"])
        let result = manager.lookupDetailed("ಬೀಸುತ್ತಿತ್ತು")

        XCTAssertEqual(result.path, .suffix)
        XCTAssertEqual(result.matchedKey, "ಬೀಸು")
        XCTAssertEqual(result.meaning, "to blow")
    }

    func testLookupTrimsEdgePunctuation() {
        let manager = makeManager(entries: ["hello": "hi"])
        let result = manager.lookupDetailed("\"hello\"")

        XCTAssertEqual(result.matchedKey, "hello")
        XCTAssertEqual(result.meaning, "hi")
        XCTAssertEqual(result.path, .suffix)
    }

    func testSourceDescription() {
        let manager = makeManager(entries: [:])
        XCTAssertEqual(manager.sourceDescription, "Bundled sample dictionary")
    }

    func testLookupMissingAndEmptyWord() {
        let manager = makeManager(entries: ["hello": "hi"])

        XCTAssertNil(manager.lookup("missing"))
        XCTAssertNil(manager.lookup(""))
        XCTAssertNil(manager.lookup("   "))
    }

    func testRedirectResolvesAndMarksPath() {
        let manager = makeManager(entries: ["ತುಂಬಾ": "= ತುಂಬ2.", "ತುಂಬ": "very"])
        let result = manager.lookupDetailed("ತುಂಬಾ")

        XCTAssertEqual(result.path, .redirect)
        XCTAssertEqual(result.matchedKey, "ತುಂಬಾ")
        XCTAssertEqual(result.meaning, "very")
    }

    func testSelfRedirectReturnsNoMeaning() {
        let manager = makeManager(entries: ["ಪದ": "= ಪದ1."])
        let result = manager.lookupDetailed("ಪದ")

        XCTAssertEqual(result.path, .none)
        XCTAssertNil(result.meaning)
    }

    func testIdentityMeaningIsDiscarded() {
        let manager = makeManager(entries: ["ಪದ": "ಪದ."])
        let result = manager.lookupDetailed("ಪದ")

        XCTAssertEqual(result.path, .none)
        XCTAssertNil(result.meaning)
    }

    func testCleanMeaningKeepsConcisePrefixForEnumeratedDefinitions() {
        let manager = makeManager(entries: ["ಪದ": "pronunciation - a) how a word is spoken; b) articulation"])
        let result = manager.lookupDetailed("ಪದ")

        XCTAssertEqual(result.meaning, "pronunciation")
    }

    func testCleanMeaningUsesFirstClauseBeforeSemicolon() {
        let manager = makeManager(entries: ["ಪದ": "meaningful clause; extra clause"])
        let result = manager.lookupDetailed("ಪದ")

        XCTAssertEqual(result.meaning, "meaningful clause")
    }

    func testOverrideTakesPrecedence() {
        let manager = makeManager(entries: ["hello": "hi"], overrides: ["hello": "override"])
        let result = manager.lookupDetailed("hello")

        XCTAssertEqual(result.path, .override)
        XCTAssertEqual(result.meaning, "override")
    }

    func testLookupReadsCloudCacheWhenLocalDictionaryMisses() {
        let cached = CachedWordMeaning(
            languageCode: "kn",
            normalizedKey: "ಮನೆ",
            meaning: "house",
            source: "remote",
            updatedAt: Date()
        )
        let manager = makeManager(entries: [:], cloudEntries: [cached], sourceLanguage: "kn")

        let result = manager.lookupDetailed("ಮನೆ")

        XCTAssertEqual(result.path, .cache)
        XCTAssertEqual(result.meaning, "house")
    }

    func testLookupWithRemoteFallbackStoresMeaningInCache() async {
        let remote = FakeRemoteWordMeaningProvider(resultsByWord: ["hola": " hello "])
        let manager = makeManager(
            entries: [:],
            remoteProvider: remote,
            sourceLanguage: "es",
            targetLanguage: "en"
        )

        let remoteResult = await manager.lookupDetailedWithRemoteFallback("hola")
        let cachedResult = manager.lookupDetailed("hola")

        XCTAssertEqual(remoteResult.path, .remote)
        XCTAssertEqual(remoteResult.meaning, "hello")
        XCTAssertEqual(cachedResult.path, .cache)
        XCTAssertEqual(cachedResult.meaning, "hello")
        let remoteCalls = await remote.lookupCallCount()
        XCTAssertEqual(remoteCalls, 1)
    }

    func testLookupWithRemoteFallbackSkipsNetworkWhenDisabled() async {
        let remote = FakeRemoteWordMeaningProvider(resultsByWord: ["hola": "hello"])
        let manager = makeManager(
            entries: [:],
            remoteProvider: remote,
            sourceLanguage: "es",
            targetLanguage: "en",
            cloudFallbackEnabled: false
        )

        let result = await manager.lookupDetailedWithRemoteFallback("hola")

        XCTAssertEqual(result.path, .none)
        XCTAssertNil(result.meaning)
        let remoteCalls = await remote.lookupCallCount()
        XCTAssertEqual(remoteCalls, 0)
    }

    func testPrefetchRemoteMeaningsDedupesAndSkipsKnownWords() async {
        let remote = FakeRemoteWordMeaningProvider(resultsByWord: ["hola": "hello"])
        let cached = CachedWordMeaning(
            languageCode: "es",
            normalizedKey: "cached",
            meaning: "cached",
            source: "remote",
            updatedAt: Date()
        )
        let manager = makeManager(
            entries: ["local": "local meaning"],
            cloudEntries: [cached],
            remoteProvider: remote,
            sourceLanguage: "es",
            targetLanguage: "en"
        )

        await manager.prefetchRemoteMeanings(for: [" local ", "hola", "HOLA", "cached", "  "])

        let remoteCalls = await remote.lookupCallCount()
        XCTAssertEqual(remoteCalls, 1)
        XCTAssertEqual(manager.cloudCacheCount(), 2)

        let lookup = manager.lookupDetailed("hola")
        XCTAssertEqual(lookup.path, .cache)
        XCTAssertEqual(lookup.meaning, "hello")
    }

    func testPrefetchRemoteMeaningsNoopWhenDisabled() async {
        let remote = FakeRemoteWordMeaningProvider(resultsByWord: ["hola": "hello"])
        let manager = makeManager(
            entries: [:],
            remoteProvider: remote,
            cloudFallbackEnabled: false
        )

        await manager.prefetchRemoteMeanings(for: ["hola"])

        let remoteCalls = await remote.lookupCallCount()
        XCTAssertEqual(remoteCalls, 0)
        XCTAssertEqual(manager.cloudCacheCount(), 0)
    }

    func testReportMissingAppendsWithoutOverwriting() throws {
        let missingURL = makeTemporaryURL(fileName: "missing.tsv")
        let manager = makeManager(entries: [:], missingURL: missingURL)

        manager.reportMissing(word: "ಮನೆಯಲಿ")
        manager.reportMissing(word: "ಹೊಸದು")

        let contents = try String(contentsOf: missingURL, encoding: .utf8)
        let lines = contents.split(separator: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("ಮನೆಯಲಿ\t"))
        XCTAssertTrue(lines[1].hasPrefix("ಹೊಸದು\t"))
    }

    func testRemoteLookupUsesTargetLanguageOverrideWhenProvided() async {
        let remote = CapturingRemoteWordMeaningProvider(resultsByWord: ["hola": "hello"])
        let manager = makeManager(
            entries: [:],
            remoteProvider: remote,
            sourceLanguage: " ES ",
            targetLanguage: "en",
            cloudFallbackTargetLanguageOverride: " DE "
        )

        _ = await manager.lookupDetailedWithRemoteFallback("hola")

        let call = await remote.lastCall()
        XCTAssertEqual(call?.sourceLanguage, "es")
        XCTAssertEqual(call?.targetLanguage, "de")
    }

    func testRemoteLookupFallsBackToDefaultTargetLanguageWhenOverrideBlank() async {
        let remote = CapturingRemoteWordMeaningProvider(resultsByWord: ["hola": "hello"])
        let manager = makeManager(
            entries: [:],
            remoteProvider: remote,
            sourceLanguage: "es",
            targetLanguage: " ",
            cloudFallbackTargetLanguageOverride: "  "
        )

        _ = await manager.lookupDetailedWithRemoteFallback("hola")

        let call = await remote.lastCall()
        XCTAssertEqual(call?.targetLanguage, "en")
    }

    func testSentenceGlossTranslation() {
        let manager = makeManager(entries: ["ನಮಸ್ಕಾರ": "hello", "ಇದು": "this", "ಮನೆ": "house"])
        let translator = SentenceGlossTranslator(dictionaryManager: manager)

        let result = translator.gloss("ನಮಸ್ಕಾರ, ಮನೆಯಲಿ ಇದು.")

        XCTAssertEqual(result.text, "hello, house this.")
        XCTAssertEqual(result.wordCount, 3)
        XCTAssertEqual(result.glossedWordCount, 3)
        XCTAssertEqual(result.coverage, 1, accuracy: 0.001)
    }

    func testSentenceGlossKeepsUnknownWords() {
        let manager = makeManager(entries: ["ಇದು": "this"])
        let translator = SentenceGlossTranslator(dictionaryManager: manager)

        let result = translator.gloss("ಅಜ್ಞಾತ ಇದು.")

        XCTAssertEqual(result.text, "ಅಜ್ಞಾತ this.")
        XCTAssertEqual(result.wordCount, 2)
        XCTAssertEqual(result.glossedWordCount, 1)
        XCTAssertEqual(result.coverage, 0.5, accuracy: 0.001)
    }
}

private actor FakeRemoteWordMeaningProvider: RemoteWordMeaningProviding {
    private let resultsByWord: [String: String]
    private var calls = 0

    init(resultsByWord: [String: String]) {
        self.resultsByWord = resultsByWord
    }

    func lookupMeaning(for word: String, sourceLanguage: String, targetLanguage: String) async -> String? {
        calls += 1
        return resultsByWord[word]
    }

    func lookupCallCount() -> Int {
        calls
    }
}

private actor CapturingRemoteWordMeaningProvider: RemoteWordMeaningProviding {
    struct Call: Equatable {
        let word: String
        let sourceLanguage: String
        let targetLanguage: String
    }

    private let resultsByWord: [String: String]
    private var last: Call?

    init(resultsByWord: [String: String]) {
        self.resultsByWord = resultsByWord
    }

    func lookupMeaning(for word: String, sourceLanguage: String, targetLanguage: String) async -> String? {
        last = Call(word: word, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        return resultsByWord[word]
    }

    func lastCall() -> Call? {
        last
    }
}
