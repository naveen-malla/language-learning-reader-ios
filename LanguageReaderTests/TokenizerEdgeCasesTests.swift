import XCTest
@testable import LanguageReader

final class TokenizerEdgeCasesTests: XCTestCase {
    private var tokenizer: Tokenizer!

    override func setUp() {
        super.setUp()
        tokenizer = Tokenizer()
    }

    func testHandlesMultipleSpaces() {
        let tokens = tokenizer.tokenize("hello    world")
        let words = tokens.filter { $0.isWord }.map { $0.text }
        XCTAssertEqual(words, ["hello", "world"])
    }

    func testHandlesMultiplePunctuation() {
        let tokens = tokenizer.tokenize("hello...world!!!")
        let words = tokens.filter { $0.isWord }.map { $0.text }
        XCTAssertEqual(words, ["hello", "world"])
    }

    func testHandlesOnlyPunctuation() {
        let tokens = tokenizer.tokenize("!!!")
        let words = tokens.filter { $0.isWord }
        XCTAssertTrue(words.isEmpty)
    }

    func testHandlesOnlyWhitespace() {
        let tokens = tokenizer.tokenize("   ")
        let words = tokens.filter { $0.isWord }
        XCTAssertTrue(words.isEmpty)
    }

    func testHandlesSingleWord() {
        let tokens = tokenizer.tokenize("hello")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].text, "hello")
        XCTAssertTrue(tokens[0].isWord)
    }

    func testHandlesNumbersAsWords() {
        let tokens = tokenizer.tokenize("123 456")
        let words = tokens.filter { $0.isWord }.map { $0.text }
        XCTAssertTrue(words.contains("123"))
        XCTAssertTrue(words.contains("456"))
    }

    func testHandlesMixedScripts() {
        let tokens = tokenizer.tokenize("Hello ನಮಸ್ಕಾರ world")
        let words = tokens.filter { $0.isWord }.map { $0.text }
        XCTAssertEqual(words.count, 3)
        XCTAssertTrue(words.contains("Hello"))
        XCTAssertTrue(words.contains("ನಮಸ್ಕಾರ"))
        XCTAssertTrue(words.contains("world"))
    }

    func testHandlesNewlines() {
        let tokens = tokenizer.tokenize("line1\nline2")
        let words = tokens.filter { $0.isWord }.map { $0.text }
        XCTAssertEqual(words, ["line1", "line2"])
    }

    func testPreservesTokenOrder() {
        let tokens = tokenizer.tokenize("word1, word2, word3")
        let allText = tokens.map { $0.text }.joined()
        XCTAssertEqual(allText, "word1, word2, word3")
    }
}
