import XCTest
@testable import LanguageReader

final class FlashcardDeckTests: XCTestCase {
    func testDueDeckIncludesOnlyDueLearningEntries() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries: [VocabEntry] = [
            VocabEntry(word: "dueNil", normalizedKey: "dueNil", meaning: "", status: .level1, dueAt: nil),
            VocabEntry(word: "duePast", normalizedKey: "duePast", meaning: "", status: .level2, dueAt: now.addingTimeInterval(-60)),
            VocabEntry(word: "notDue", normalizedKey: "notDue", meaning: "", status: .level3, dueAt: now.addingTimeInterval(3600)),
            VocabEntry(word: "known", normalizedKey: "known", meaning: "", status: .known, dueAt: nil),
            VocabEntry(word: "suspended", normalizedKey: "suspended", meaning: "", status: .level1, dueAt: nil, isSuspended: true)
        ]

        let review = FlashcardDeck.dueEntries(from: entries, now: now)

        XCTAssertEqual(review.map(\.normalizedKey), ["dueNil", "duePast"])
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

    func testSessionPromptsIncludeBothDirectionsForEachDueWord() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let first = VocabEntry(
            word: "first",
            normalizedKey: "first",
            meaning: "",
            status: .level1,
            createdAt: now,
            lastSeenAt: now,
            dueAt: now.addingTimeInterval(-120)
        )

        let second = VocabEntry(
            word: "second",
            normalizedKey: "second",
            meaning: "",
            status: .level2,
            createdAt: now,
            lastSeenAt: now,
            dueAt: now.addingTimeInterval(-60)
        )

        let notDue = VocabEntry(
            word: "notDue",
            normalizedKey: "notDue",
            meaning: "",
            status: .level3,
            createdAt: now,
            lastSeenAt: now,
            dueAt: now.addingTimeInterval(3600)
        )

        let prompts = FlashcardDeck.sessionPrompts(from: [first, second, notDue], now: now)

        XCTAssertEqual(prompts.count, 4)
        XCTAssertEqual(prompts[0], FlashcardPrompt(entryID: first.id, direction: .wordToMeaning))
        XCTAssertEqual(prompts[1], FlashcardPrompt(entryID: first.id, direction: .meaningToWord))
        XCTAssertEqual(prompts[2], FlashcardPrompt(entryID: second.id, direction: .wordToMeaning))
        XCTAssertEqual(prompts[3], FlashcardPrompt(entryID: second.id, direction: .meaningToWord))
    }

    func testSessionPromptsRespectWordLimitAndStillEmitTwoCardsPerWord() {
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

        let prompts = FlashcardDeck.sessionPrompts(from: entries, now: now, limit: 5)

        XCTAssertEqual(prompts.count, 10)
        XCTAssertEqual(Set(prompts.map(\.entryID)).count, 5)
        let grouped = Dictionary(grouping: prompts, by: \.entryID)
        XCTAssertTrue(grouped.values.allSatisfy { promptsForWord in
            Set(promptsForWord.map(\.direction)) == Set(FlashcardDirection.allCases)
        })
    }

    func testRoundEvaluatorPromotesAfterTwoPerfectRounds() {
        let firstRound = FlashcardRoundEvaluator.evaluate(
            status: .level1,
            consecutiveSuccessRounds: 0,
            answers: [.correct, .correct]
        )

        XCTAssertEqual(firstRound.status, .level1)
        XCTAssertEqual(firstRound.nextConsecutiveSuccessRounds, 1)
        XCTAssertFalse(firstRound.shouldRequeue)

        let secondRound = FlashcardRoundEvaluator.evaluate(
            status: firstRound.status,
            consecutiveSuccessRounds: firstRound.nextConsecutiveSuccessRounds,
            answers: [.correct, .correct]
        )

        XCTAssertEqual(secondRound.status, .level2)
        XCTAssertEqual(secondRound.nextConsecutiveSuccessRounds, 0)
        XCTAssertFalse(secondRound.shouldRequeue)
    }

    func testRoundEvaluatorOneWrongKeepsLevelAndResetsStreak() {
        let outcome = FlashcardRoundEvaluator.evaluate(
            status: .level3,
            consecutiveSuccessRounds: 1,
            answers: [.correct, .wrong]
        )

        XCTAssertEqual(outcome.status, .level3)
        XCTAssertEqual(outcome.nextConsecutiveSuccessRounds, 0)
        XCTAssertTrue(outcome.shouldRequeue)
    }

    func testRoundEvaluatorBothWrongDemotesByOneLevel() {
        let outcome = FlashcardRoundEvaluator.evaluate(
            status: .level4,
            consecutiveSuccessRounds: 1,
            answers: [.wrong, .wrong]
        )

        XCTAssertEqual(outcome.status, .level3)
        XCTAssertEqual(outcome.nextConsecutiveSuccessRounds, 0)
        XCTAssertTrue(outcome.shouldRequeue)
    }

    func testRoundEvaluatorCapsPromotionAtLevel4() {
        let outcome = FlashcardRoundEvaluator.evaluate(
            status: .level4,
            consecutiveSuccessRounds: 1,
            answers: [.correct, .correct]
        )

        XCTAssertEqual(outcome.status, .level4)
        XCTAssertEqual(outcome.nextConsecutiveSuccessRounds, 0)
        XCTAssertFalse(outcome.shouldRequeue)
    }

    func testSchedulerIntervalsMatchLevelBuckets() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(SimpleLevelScheduler.intervalDays(for: .level1), 1)
        XCTAssertEqual(SimpleLevelScheduler.intervalDays(for: .level2), 3)
        XCTAssertEqual(SimpleLevelScheduler.intervalDays(for: .level3), 7)
        XCTAssertEqual(SimpleLevelScheduler.intervalDays(for: .level4), 15)
        XCTAssertNil(SimpleLevelScheduler.intervalDays(for: .known))

        let due = SimpleLevelScheduler.dueDate(for: .level3, baseDate: base)
        XCTAssertNotNil(due)
        XCTAssertEqual(due!.timeIntervalSince1970, base.addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970, accuracy: 1)
        XCTAssertNil(SimpleLevelScheduler.dueDate(for: .known, baseDate: base))
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
}
