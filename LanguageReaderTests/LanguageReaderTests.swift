import XCTest
@testable import LanguageReader

final class LanguageReaderTests: XCTestCase {
    func testDocumentInitialization() {
        let date = Date()
        let document = Document(title: "Title", body: "Body", createdAt: date, updatedAt: date)

        XCTAssertEqual(document.title, "Title")
        XCTAssertEqual(document.body, "Body")
        XCTAssertEqual(document.createdAt, date)
        XCTAssertEqual(document.updatedAt, date)
    }

    func testVocabEntryDefaults() {
        let entry = VocabEntry(word: "Hello", normalizedKey: "hello", meaning: "hi")

        XCTAssertEqual(entry.word, "Hello")
        XCTAssertEqual(entry.normalizedKey, "hello")
        XCTAssertEqual(entry.meaning, "hi")
        XCTAssertEqual(entry.status, .new)
        XCTAssertEqual(entry.encounterCount, 1)
    }

    func testVocabEntryCustomInitialization() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let lastSeenAt = Date(timeIntervalSince1970: 200)
        let entry = VocabEntry(
            word: "ಮನೆ",
            normalizedKey: "ಮನೆ",
            meaning: "house",
            status: .learning,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt,
            encounterCount: 7
        )

        XCTAssertEqual(entry.status, .learning)
        XCTAssertEqual(entry.createdAt, createdAt)
        XCTAssertEqual(entry.lastSeenAt, lastSeenAt)
        XCTAssertEqual(entry.encounterCount, 7)
    }
}
