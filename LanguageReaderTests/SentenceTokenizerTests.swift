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
}
