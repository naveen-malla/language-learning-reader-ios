import XCTest
@testable import LanguageReader

final class SentenceReaderModelTests: XCTestCase {
    func testModelFiltersOutEmptyBlocks() {
        let blocks: [SentenceBlock] = [
            SentenceBlock(id: 0, text: "ಮೊದಲ ವಾಕ್ಯ.", isEmpty: false),
            SentenceBlock(id: 1, text: "", isEmpty: true),
            SentenceBlock(id: 2, text: "ಎರಡನೇ ವಾಕ್ಯ.", isEmpty: false)
        ]

        let model = SentenceReaderModel(blocks: blocks)

        XCTAssertEqual(model.sentences.count, 2)
        XCTAssertEqual(model.sentences.map(\.id), [0, 2])
    }

    func testClampedIndexBounds() {
        let model = SentenceReaderModel(
            blocks: [
                SentenceBlock(id: 0, text: "ಒಂದು.", isEmpty: false),
                SentenceBlock(id: 1, text: "ಎರಡು.", isEmpty: false)
            ]
        )

        XCTAssertEqual(model.clampedIndex(-4), 0)
        XCTAssertEqual(model.clampedIndex(1), 1)
        XCTAssertEqual(model.clampedIndex(100), 1)
    }

    func testProgressAcrossSentencePages() {
        let model = SentenceReaderModel(
            blocks: [
                SentenceBlock(id: 0, text: "A", isEmpty: false),
                SentenceBlock(id: 1, text: "B", isEmpty: false),
                SentenceBlock(id: 2, text: "C", isEmpty: false)
            ]
        )

        XCTAssertEqual(model.progress(for: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(model.progress(for: 1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(model.progress(for: 2), 1, accuracy: 0.0001)
    }

    func testIndexForProgressRoundsToClosestSentencePage() {
        let model = SentenceReaderModel(
            blocks: [
                SentenceBlock(id: 0, text: "A", isEmpty: false),
                SentenceBlock(id: 1, text: "B", isEmpty: false),
                SentenceBlock(id: 2, text: "C", isEmpty: false),
                SentenceBlock(id: 3, text: "D", isEmpty: false)
            ]
        )

        XCTAssertEqual(model.index(for: 0), 0)
        XCTAssertEqual(model.index(for: 0.32), 1)
        XCTAssertEqual(model.index(for: 0.51), 2)
        XCTAssertEqual(model.index(for: 1), 3)
        XCTAssertEqual(model.index(for: 7), 3)
        XCTAssertEqual(model.index(for: -2), 0)
    }

    func testPanelWordFilterExcludesKnownWordsAndPreservesOrder() {
        let words: [SentenceWordInsight] = [
            SentenceWordInsight(
                id: "a#0",
                word: "ಅಲ್ಲಿ",
                normalizedKey: "alli",
                meaning: "there",
                pronunciation: "alli"
            ),
            SentenceWordInsight(
                id: "b#1",
                word: "ಜನರ",
                normalizedKey: "janara",
                meaning: "people's",
                pronunciation: "janara"
            ),
            SentenceWordInsight(
                id: "c#2",
                word: "ಮಾತು",
                normalizedKey: "matu",
                meaning: "speech",
                pronunciation: "matu"
            )
        ]

        let visible = SentencePanelWordFilter.visibleWords(
            from: words,
            statusByKey: [
                "alli": .learning,
                "janara": .known
            ]
        )

        XCTAssertEqual(visible.map(\.normalizedKey), ["alli", "matu"])
    }
}
