import XCTest
@testable import LanguageReader

final class DictionaryManagerTests: XCTestCase {
    private func makeManager(provider: DictionaryProvider) -> DictionaryManager {
        DictionaryManager(
            provider: provider,
            overrideStore: DictionaryOverrideStore(fileURL: nil, missingURL: nil)
        )
    }

    func testLookupWithWhitespace() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = makeManager(provider: provider)

        XCTAssertEqual(manager.lookup("  hello  "), "hi")
        XCTAssertEqual(manager.lookup("\nhello\t"), "hi")
    }

    func testLookupWithMixedCase() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = makeManager(provider: provider)

        XCTAssertEqual(manager.lookup("HELLO"), "hi")
        XCTAssertEqual(manager.lookup("HeLLo"), "hi")
    }

    func testLookupMissingWord() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = makeManager(provider: provider)

        XCTAssertNil(manager.lookup("missing"))
        XCTAssertNil(manager.lookup(""))
    }

    func testLookupEmptyString() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = makeManager(provider: provider)

        XCTAssertNil(manager.lookup(""))
        XCTAssertNil(manager.lookup("   "))
    }

    func testSourceDescription() {
        let provider = SampleDictionaryProvider()
        let manager = makeManager(provider: provider)

        XCTAssertEqual(manager.sourceDescription, "Bundled sample dictionary")
    }

    func testLookupKannadaWords() {
        let provider = SampleDictionaryProvider()
        let manager = makeManager(provider: provider)

        XCTAssertEqual(manager.lookup("ನಮಸ್ಕಾರ"), "hello")
        XCTAssertEqual(manager.lookup("  ನಮಸ್ಕಾರ  "), "hello")
    }

    func testLookupWithSuffixFallback() {
        let provider = SampleDictionaryProvider()
        let manager = makeManager(provider: provider)

        XCTAssertEqual(manager.lookup("ಮನೆಯಲ್ಲಿ"), "house")
    }

    func testMeaningCleanup() {
        let provider = SampleDictionaryProvider(entries: ["ತುಂಬಾ": "= ತುಂಬ2.", "ತುಂಬ": "very"])
        let manager = makeManager(provider: provider)

        XCTAssertEqual(manager.lookup("ತುಂಬಾ"), "very")
    }

    func testOverrideTakesPrecedence() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let overrides = DictionaryOverrideStore(
            fileURL: nil,
            missingURL: nil,
            overrides: ["hello": "override"]
        )
        let manager = DictionaryManager(provider: provider, overrideStore: overrides)

        XCTAssertEqual(manager.lookup("hello"), "override")
    }

    func testSentenceGlossTranslation() {
        let provider = SampleDictionaryProvider(entries: [
            "ನಮಸ್ಕಾರ": "hello",
            "ಇದು": "this",
            "ಪಠ್ಯ": "text"
        ])
        let manager = makeManager(provider: provider)
        let translator = SentenceGlossTranslator(dictionaryManager: manager)

        let result = translator.gloss("ನಮಸ್ಕಾರ, ಇದು ಪಠ್ಯ.")

        XCTAssertEqual(result.text, "hello, this text.")
        XCTAssertEqual(result.wordCount, 3)
        XCTAssertEqual(result.glossedWordCount, 3)
        XCTAssertEqual(result.coverage, 1, accuracy: 0.001)
    }

    func testSentenceGlossKeepsUnknownWords() {
        let provider = SampleDictionaryProvider(entries: [
            "ಇದು": "this"
        ])
        let manager = makeManager(provider: provider)
        let translator = SentenceGlossTranslator(dictionaryManager: manager)

        let result = translator.gloss("ಅಜ್ಞಾತ ಇದು.")

        XCTAssertEqual(result.text, "ಅಜ್ಞಾತ this.")
        XCTAssertEqual(result.wordCount, 2)
        XCTAssertEqual(result.glossedWordCount, 1)
        XCTAssertEqual(result.coverage, 0.5, accuracy: 0.001)
    }
}
