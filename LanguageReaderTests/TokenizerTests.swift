import XCTest
@testable import LanguageReader

final class TokenizerTests: XCTestCase {
    private let tokenizer = Tokenizer()

    func testTokenizesWordsAndPunctuation() {
        let tokens = tokenizer.tokenize("hello, world!")
        let simplified = tokens.map { ($0.text, $0.isWord) }

        XCTAssertEqual(simplified.count, 4)
        XCTAssertEqual(simplified[0].0, "hello")
        XCTAssertTrue(simplified[0].1)
        XCTAssertEqual(simplified[1].0, ", ")
        XCTAssertFalse(simplified[1].1)
        XCTAssertEqual(simplified[2].0, "world")
        XCTAssertTrue(simplified[2].1)
        XCTAssertEqual(simplified[3].0, "!")
        XCTAssertFalse(simplified[3].1)
    }

    func testTokenizesKannadaText() {
        let tokens = tokenizer.tokenize("ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷೆ.")
        let words = tokens.filter { $0.isWord }.map { $0.text }

        XCTAssertTrue(words.contains("ನಮಸ್ಕಾರ"))
        XCTAssertTrue(words.contains("ಇದು"))
        XCTAssertTrue(words.contains("ಪರೀಕ್ಷೆ"))
    }

    func testTokenizesEmptyText() {
        let tokens = tokenizer.tokenize("")
        XCTAssertTrue(tokens.isEmpty)
    }

    func testRoundTripPreservesOriginalTextForMixedContent() {
        let input = "VC #011, ಇದು ಪರೀಕ್ಷೆ! \"hello\" world."
        let tokens = tokenizer.tokenize(input)
        let reconstructed = tokens.map(\.text).joined()

        XCTAssertEqual(reconstructed, input)
    }

    func testTokenIdsAreUniquePerToken() {
        let tokens = tokenizer.tokenize("one two three")
        let ids = Set(tokens.map(\.id))

        XCTAssertEqual(ids.count, tokens.count)
    }
}
