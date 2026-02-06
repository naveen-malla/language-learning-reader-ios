import XCTest
@testable import LanguageReader

final class SentenceTokenizerTests: XCTestCase {
    private let tokenizer = SentenceTokenizer()

    func testSplitsSentences() {
        let text = "ಒಂದು ವಾಕ್ಯ. ಎರಡನೇ ವಾಕ್ಯ?"
        let sentences = tokenizer.sentences(in: text)
        XCTAssertEqual(sentences.count, 2)
    }

    func testTrimsWhitespace() {
        let text = " ಮೊದಲ ವಾಕ್ಯ.  ಎರಡನೇ ವಾಕ್ಯ. "
        let sentences = tokenizer.sentences(in: text)
        XCTAssertEqual(sentences.first, "ಮೊದಲ ವಾಕ್ಯ.")
    }

    func testReturnsEmptyForWhitespaceOnlyInput() {
        XCTAssertEqual(tokenizer.sentences(in: "   \n\t ").count, 0)
    }

    func testReturnsSingleSentenceWhenNoBoundaryPunctuation() {
        let text = "ಇದು ಒಂದೇ ವಾಕ್ಯ"
        let sentences = tokenizer.sentences(in: text)

        XCTAssertEqual(sentences, [text])
    }

    func testPreservesSentenceOrderAcrossLines() {
        let text = "ಮೊದಲ ವಾಕ್ಯ.\nಎರಡನೇ ವಾಕ್ಯ?\nಮೂರನೇ ವಾಕ್ಯ!"
        let sentences = tokenizer.sentences(in: text)

        XCTAssertEqual(sentences.count, 3)
        XCTAssertEqual(sentences[0], "ಮೊದಲ ವಾಕ್ಯ.")
        XCTAssertEqual(sentences[1], "ಎರಡನೇ ವಾಕ್ಯ?")
        XCTAssertEqual(sentences[2], "ಮೂರನೇ ವಾಕ್ಯ!")
    }
}
