import XCTest
@testable import LanguageReader

final class DictionaryManagerTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        let fileManager = FileManager.default
        for url in cleanupURLs {
            try? fileManager.removeItem(at: url)
        }
        cleanupURLs.removeAll()
        super.tearDown()
    }

    private func makeManager(
        entries: [String: String],
        overrides: [String: String] = [:],
        missingURL: URL? = nil
    ) -> DictionaryManager {
        let provider = SampleDictionaryProvider(entries: entries)
        let overrideStore = DictionaryOverrideStore(
            fileURL: nil,
            missingURL: missingURL,
            overrides: overrides
        )
        return DictionaryManager(provider: provider, overrideStore: overrideStore)
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

    func testOverrideTakesPrecedence() {
        let manager = makeManager(entries: ["hello": "hi"], overrides: ["hello": "override"])
        let result = manager.lookupDetailed("hello")

        XCTAssertEqual(result.path, .override)
        XCTAssertEqual(result.meaning, "override")
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
