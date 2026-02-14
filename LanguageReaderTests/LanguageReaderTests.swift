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
        XCTAssertEqual(entry.status, .level1)
        XCTAssertEqual(entry.encounterCount, 1)
        XCTAssertNil(entry.dueAt)
        XCTAssertEqual(entry.srsIntervalDays ?? -1, 0)
        XCTAssertEqual(entry.srsEaseFactor ?? -1, 2.5)
        XCTAssertEqual(entry.srsRepetition ?? -1, 0)
        XCTAssertEqual(entry.srsLapseCount ?? -1, 0)
        XCTAssertEqual(entry.isSuspended, false)
        XCTAssertNil(entry.srsStability)
        XCTAssertNil(entry.srsDifficulty)
        XCTAssertNil(entry.srsAlgorithm)
    }

    func testVocabEntryCustomInitialization() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let lastSeenAt = Date(timeIntervalSince1970: 200)
        let entry = VocabEntry(
            word: "ಮನೆ",
            normalizedKey: "ಮನೆ",
            meaning: "house",
            status: .level2,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt,
            encounterCount: 7,
            dueAt: Date(timeIntervalSince1970: 300),
            srsIntervalDays: 6,
            srsEaseFactor: 2.2,
            srsRepetition: 3,
            srsLapseCount: 1,
            isSuspended: true,
            srsStability: 4.5,
            srsDifficulty: 6.2,
            srsAlgorithm: "fsrs"
        )

        XCTAssertEqual(entry.status, .level2)
        XCTAssertEqual(entry.createdAt, createdAt)
        XCTAssertEqual(entry.lastSeenAt, lastSeenAt)
        XCTAssertEqual(entry.encounterCount, 7)
        XCTAssertEqual(entry.dueAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(entry.srsIntervalDays ?? -1, 6)
        XCTAssertEqual(entry.srsEaseFactor ?? -1, 2.2)
        XCTAssertEqual(entry.srsRepetition ?? -1, 3)
        XCTAssertEqual(entry.srsLapseCount ?? -1, 1)
        XCTAssertEqual(entry.isSuspended, true)
        XCTAssertEqual(entry.srsStability, 4.5)
        XCTAssertEqual(entry.srsDifficulty, 6.2)
        XCTAssertEqual(entry.srsAlgorithm, "fsrs")
    }
}
