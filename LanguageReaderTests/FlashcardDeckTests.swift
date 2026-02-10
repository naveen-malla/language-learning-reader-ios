import XCTest
@testable import LanguageReader

final class FlashcardDeckTests: XCTestCase {
    func testReviewDeckIncludesOnlyLearningLevels() {
        let entries: [VocabEntry] = [
            VocabEntry(word: "one", normalizedKey: "one", meaning: "1", status: .level1),
            VocabEntry(word: "two", normalizedKey: "two", meaning: "2", status: .level3),
            VocabEntry(word: "three", normalizedKey: "three", meaning: "3", status: .known)
        ]

        let review = FlashcardDeck.reviewEntries(from: entries)

        XCTAssertEqual(review.map(\.normalizedKey), ["one", "two"])
    }
}
