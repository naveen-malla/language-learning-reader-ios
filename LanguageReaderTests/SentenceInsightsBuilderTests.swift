import XCTest
@testable import LanguageReader

final class SentenceInsightsBuilderTests: XCTestCase {
    private func makeBuilder(entries: [String: String]) -> SentenceInsightsBuilder {
        let manager = DictionaryManager(
            provider: SampleDictionaryProvider(entries: entries),
            overrideStore: DictionaryOverrideStore(fileURL: nil, missingURL: nil)
        )
        return SentenceInsightsBuilder(dictionaryManager: manager)
    }

    func testBuildPreservesFirstAppearanceOrderAndDeduplicatesWords() {
        let builder = makeBuilder(entries: ["ಮನೆ": "house", "ಇದು": "this"])

        let result = builder.build(for: "ಇದು ಮನೆ. ಇದು ಮನೆ.")

        XCTAssertEqual(result.words.map(\.word), ["ಇದು", "ಮನೆ"])
        XCTAssertEqual(result.words.map(\.meaning), ["this", "house"])
    }

    func testBuildIncludesMissingMeaningAsNil() {
        let builder = makeBuilder(entries: ["ಮನೆ": "house"])

        let result = builder.build(for: "ಮನೆ ಅಜ್ಞಾತ")

        XCTAssertEqual(result.words.count, 2)
        XCTAssertEqual(result.words[0].meaning, "house")
        XCTAssertNil(result.words[1].meaning)
    }

    func testBuildAddsPronunciationForEachWord() {
        let builder = makeBuilder(entries: ["ಕನ್ನಡ": "kannada"])

        let result = builder.build(for: "ಕನ್ನಡ")

        XCTAssertEqual(result.words.count, 1)
        XCTAssertEqual(result.words[0].pronunciation, "kannada")
    }
}
