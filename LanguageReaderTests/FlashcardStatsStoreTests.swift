import XCTest
@testable import LanguageReader

final class FlashcardStatsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FlashcardStatsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordTracksTodayCounts() {
        let calendar = Calendar(identifier: .gregorian)
        let store = FlashcardStatsStore(
            defaults: defaults,
            calendar: calendar,
            storageKey: "stats"
        )

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.record(answer: .correct, at: date)
        store.record(answer: .wrong, at: date)

        XCTAssertEqual(store.stats(for: date), FlashcardDailyStats(reviewed: 2, correct: 1))
    }

    func testRecentStatsAggregatesRequestedDays() {
        let calendar = Calendar(identifier: .gregorian)
        let store = FlashcardStatsStore(
            defaults: defaults,
            calendar: calendar,
            storageKey: "stats"
        )

        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        store.record(answer: .correct, at: today)
        store.record(answer: .wrong, at: today)
        store.record(answer: .correct, at: yesterday)

        let recent = store.recentStats(days: 2, upTo: today)

        XCTAssertEqual(recent.reviewed, 3)
        XCTAssertEqual(recent.correct, 2)
        XCTAssertEqual(recent.averageReviewsPerDay, 1.5, accuracy: 0.001)
        XCTAssertEqual(recent.accuracy, 2.0 / 3.0, accuracy: 0.001)
    }
}
