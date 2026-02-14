import XCTest
@testable import LanguageReader

final class FlashcardDeckTests: XCTestCase {
    func testDueDeckIncludesOnlyDueLearningEntries() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries: [VocabEntry] = [
            VocabEntry(word: "dueNew", normalizedKey: "dueNew", meaning: "", status: .level1, dueAt: nil),
            VocabEntry(word: "duePast", normalizedKey: "duePast", meaning: "", status: .level2, dueAt: now.addingTimeInterval(-60)),
            VocabEntry(word: "notDue", normalizedKey: "notDue", meaning: "", status: .level3, dueAt: now.addingTimeInterval(3600)),
            VocabEntry(word: "known", normalizedKey: "known", meaning: "", status: .known, dueAt: nil),
            VocabEntry(word: "suspended", normalizedKey: "suspended", meaning: "", status: .level1, dueAt: nil, isSuspended: true)
        ]

        let review = FlashcardDeck.reviewEntries(from: entries, now: now)

        XCTAssertEqual(review.map(\.normalizedKey), ["dueNew", "duePast"])
    }

    func testDueDeckSortsByDueDateThenLastSeen() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries: [VocabEntry] = [
            VocabEntry(
                word: "later",
                normalizedKey: "later",
                meaning: "",
                status: .level2,
                createdAt: now,
                lastSeenAt: now,
                dueAt: now.addingTimeInterval(300)
            ),
            VocabEntry(
                word: "earlierA",
                normalizedKey: "earlierA",
                meaning: "",
                status: .level2,
                createdAt: now,
                lastSeenAt: now.addingTimeInterval(-20),
                dueAt: now.addingTimeInterval(120)
            ),
            VocabEntry(
                word: "earlierB",
                normalizedKey: "earlierB",
                meaning: "",
                status: .level2,
                createdAt: now,
                lastSeenAt: now.addingTimeInterval(-50),
                dueAt: now.addingTimeInterval(120)
            )
        ]

        let due = FlashcardDeck.dueEntries(from: entries, now: now.addingTimeInterval(600))

        XCTAssertEqual(due.map(\.normalizedKey), ["earlierB", "earlierA", "later"])
    }

    func testSessionQueueUsesDueEntriesAndLimit() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries: [VocabEntry] = (0..<8).map { index in
            VocabEntry(
                word: "w\(index)",
                normalizedKey: "w\(index)",
                meaning: "",
                status: .level1,
                createdAt: now,
                lastSeenAt: now,
                dueAt: now.addingTimeInterval(TimeInterval(-index * 60))
            )
        }

        let queue = FlashcardDeck.sessionQueueIDs(from: entries, now: now, limit: 3)

        XCTAssertEqual(queue.count, 3)
    }

    func testSM2GoodOnNewCardSchedulesOneDayAndPromotesLevel() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = VocabEntry(word: "word", normalizedKey: "word", meaning: "", status: .level1)
        let scheduler = SM2Scheduler()

        scheduler.apply(rating: .good, to: entry, now: now)

        XCTAssertEqual(entry.srsRepetition ?? -1, 1)
        XCTAssertEqual(entry.srsIntervalDays ?? -1, 1)
        XCTAssertEqual(entry.status, .level2)
        guard let dueAt = entry.dueAt else {
            XCTFail("Expected due date after applying a review")
            return
        }
        XCTAssertEqual(dueAt.timeIntervalSince1970, now.addingTimeInterval(24 * 60 * 60).timeIntervalSince1970, accuracy: 1)
    }

    func testSM2AgainResetsRepetitionAddsLapseAndSchedulesTenMinutes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = VocabEntry(
            word: "word",
            normalizedKey: "word",
            meaning: "",
            status: .level3,
            srsIntervalDays: 6,
            srsEaseFactor: 2.3,
            srsRepetition: 3,
            srsLapseCount: 0
        )
        let scheduler = SM2Scheduler()

        scheduler.apply(rating: .again, to: entry, now: now)

        XCTAssertEqual(entry.srsRepetition ?? -1, 0)
        XCTAssertEqual(entry.srsIntervalDays ?? -1, 0)
        XCTAssertEqual(entry.srsLapseCount ?? -1, 1)
        XCTAssertEqual(entry.status, .level1)
        guard let dueAt = entry.dueAt else {
            XCTFail("Expected due date after applying a review")
            return
        }
        XCTAssertEqual(dueAt.timeIntervalSince1970, now.addingTimeInterval(10 * 60).timeIntervalSince1970, accuracy: 1)
    }

    func testSM2HardOnNewCardSchedulesShortRelearnAndDoesNotGraduate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = VocabEntry(word: "word", normalizedKey: "word", meaning: "", status: .level3)
        let scheduler = SM2Scheduler()

        scheduler.apply(rating: .hard, to: entry, now: now)

        XCTAssertEqual(entry.srsRepetition ?? -1, 0)
        XCTAssertEqual(entry.srsIntervalDays ?? -1, 0)
        XCTAssertEqual(entry.status, .level2)
        guard let dueAt = entry.dueAt else {
            XCTFail("Expected due date after applying a review")
            return
        }
        XCTAssertEqual(dueAt.timeIntervalSince1970, now.addingTimeInterval(30 * 60).timeIntervalSince1970, accuracy: 1)
    }

    func testFSRSGoodOnNewCardPersistsAdaptiveState() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = VocabEntry(word: "word", normalizedKey: "word", meaning: "", status: .level1)
        let scheduler = FSRSScheduler()

        scheduler.apply(rating: .good, to: entry, now: now)

        XCTAssertEqual(entry.srsAlgorithm, SpacedRepetitionAlgorithm.fsrs.rawValue)
        XCTAssertEqual(entry.srsRepetition ?? -1, 1)
        XCTAssertEqual(entry.status, .level2)
        XCTAssertEqual(entry.srsIntervalDays ?? 0, 2, accuracy: 0.001)
        XCTAssertEqual(entry.srsStability ?? 0, 1.2, accuracy: 0.001)
        XCTAssertNotNil(entry.srsDifficulty)
    }

    func testFSRSEasyHasLongerPreviewThanGoodForSameCard() {
        let entry = VocabEntry(
            word: "word",
            normalizedKey: "word",
            meaning: "",
            status: .level3,
            srsIntervalDays: 4,
            srsRepetition: 4,
            srsStability: 4.0,
            srsDifficulty: 5.0
        )
        let scheduler = FSRSScheduler()

        let good = scheduler.previewInterval(for: entry, rating: .good)
        let easy = scheduler.previewInterval(for: entry, rating: .easy)

        XCTAssertGreaterThan(easy, good)
    }

    func testAdaptiveEngineDefaultsToFSRS() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = VocabEntry(word: "word", normalizedKey: "word", meaning: "", status: .level1)
        let scheduler = SpacedRepetitionEngine()

        scheduler.apply(rating: .good, to: entry, now: now)

        XCTAssertEqual(entry.srsAlgorithm, SpacedRepetitionAlgorithm.fsrs.rawValue)
    }

    func testAdaptiveEngineCanFallbackToSM2() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = VocabEntry(word: "word", normalizedKey: "word", meaning: "", status: .level1)
        let scheduler = SpacedRepetitionEngine(algorithm: .sm2)

        scheduler.apply(rating: .good, to: entry, now: now)

        XCTAssertEqual(entry.srsAlgorithm, SpacedRepetitionAlgorithm.sm2.rawValue)
    }

    func testFSRSAgainOnReviewedCardResetsAndIncrementsLapses() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = VocabEntry(
            word: "word",
            normalizedKey: "word",
            meaning: "",
            status: .level4,
            srsIntervalDays: 12,
            srsRepetition: 5,
            srsLapseCount: 1,
            srsStability: 7.0,
            srsDifficulty: 5.4
        )
        let scheduler = FSRSScheduler()

        scheduler.apply(rating: .again, to: entry, now: now)

        XCTAssertEqual(entry.status, .level1)
        XCTAssertEqual(entry.srsRepetition ?? -1, 0)
        XCTAssertEqual(entry.srsLapseCount ?? -1, 2)
        XCTAssertEqual(entry.srsAlgorithm, SpacedRepetitionAlgorithm.fsrs.rawValue)
        guard let dueAt = entry.dueAt else {
            XCTFail("Expected due date after applying a review")
            return
        }
        XCTAssertEqual(dueAt.timeIntervalSince1970, now.addingTimeInterval(10 * 60).timeIntervalSince1970, accuracy: 1)
    }

    func testNextDueDateIgnoresKnownAndSuspendedCards() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            VocabEntry(word: "known", normalizedKey: "known", meaning: "", status: .known, dueAt: now.addingTimeInterval(300)),
            VocabEntry(word: "s1", normalizedKey: "s1", meaning: "", status: .level1, dueAt: now.addingTimeInterval(100), isSuspended: true),
            VocabEntry(word: "l1", normalizedKey: "l1", meaning: "", status: .level2, dueAt: now.addingTimeInterval(200)),
            VocabEntry(word: "l2", normalizedKey: "l2", meaning: "", status: .level3, dueAt: now.addingTimeInterval(400))
        ]

        let nextDue = FlashcardDeck.nextDueDate(from: entries, now: now)

        XCTAssertEqual(nextDue, now.addingTimeInterval(200))
    }

    func testIntervalLabelUsesMinutesHoursAndDays() {
        XCTAssertEqual(FlashcardDeck.intervalLabel(for: 4 * 60), "4m")
        XCTAssertEqual(FlashcardDeck.intervalLabel(for: 3 * 60 * 60), "3h")
        XCTAssertEqual(FlashcardDeck.intervalLabel(for: 2 * 24 * 60 * 60), "2d")
    }
}
