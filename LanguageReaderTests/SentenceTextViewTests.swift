import XCTest
@testable import LanguageReader

final class SentenceTextViewTests: XCTestCase {
    func testBlocksSplitSentencesAndPreserveEmptyParagraphs() {
        let text = "ಮೊದಲ ವಾಕ್ಯ. ಎರಡನೇ ವಾಕ್ಯ?\n\nಮೂರನೇ ವಾಕ್ಯ!"
        let blocks = SentenceTextView.blocks(from: text)

        XCTAssertEqual(blocks.count, 4)
        XCTAssertFalse(blocks[0].isEmpty)
        XCTAssertFalse(blocks[1].isEmpty)
        XCTAssertTrue(blocks[2].isEmpty)
        XCTAssertFalse(blocks[3].isEmpty)
        XCTAssertEqual(blocks[0].id, 0)
        XCTAssertEqual(blocks[3].id, 3)
    }

    func testBlocksReturnEmptyForWhitespaceOnlyInput() {
        let blocks = SentenceTextView.blocks(from: "   \n\t  ")

        XCTAssertEqual(blocks.count, 2)
        XCTAssertTrue(blocks.allSatisfy(\.isEmpty))
    }
}
