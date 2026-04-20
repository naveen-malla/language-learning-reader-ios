import Foundation

struct FlashcardDailyStats: Codable, Equatable {
    var reviewed: Int
    var correct: Int

    static let zero = FlashcardDailyStats(reviewed: 0, correct: 0)
}

struct FlashcardRecentStats: Equatable {
    let reviewed: Int
    let correct: Int
    let averageReviewsPerDay: Double

    var accuracy: Double {
        guard reviewed > 0 else { return 0 }
        return Double(correct) / Double(reviewed)
    }
}

final class FlashcardStatsStore {
    static let shared = FlashcardStatsStore()

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        storageKey: String = "flashcards.daily_stats.v1"
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.storageKey = storageKey
    }

    func record(
        answer: FlashcardBinaryAnswer,
        languageCode: String = SupportedLanguage.legacyDefault.rawValue,
        at date: Date = Date()
    ) {
        var table = loadTable(languageCode: languageCode)
        let key = dayKey(for: date)
        var day = table[key] ?? .zero
        day.reviewed += 1
        if answer == .correct {
            day.correct += 1
        }
        table[key] = day
        saveTable(table, languageCode: languageCode)
    }

    func stats(
        languageCode: String = SupportedLanguage.legacyDefault.rawValue,
        for date: Date = Date()
    ) -> FlashcardDailyStats {
        let table = loadTable(languageCode: languageCode)
        return table[dayKey(for: date)] ?? .zero
    }

    func recentStats(
        languageCode: String = SupportedLanguage.legacyDefault.rawValue,
        days: Int,
        upTo endDate: Date = Date()
    ) -> FlashcardRecentStats {
        guard days > 0 else {
            return FlashcardRecentStats(reviewed: 0, correct: 0, averageReviewsPerDay: 0)
        }

        let table = loadTable(languageCode: languageCode)
        var reviewed = 0
        var correct = 0

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else {
                continue
            }
            let day = table[dayKey(for: date)] ?? .zero
            reviewed += day.reviewed
            correct += day.correct
        }

        return FlashcardRecentStats(
            reviewed: reviewed,
            correct: correct,
            averageReviewsPerDay: Double(reviewed) / Double(days)
        )
    }

    private func dayKey(for date: Date) -> String {
        String(Int(calendar.startOfDay(for: date).timeIntervalSince1970))
    }

    private func storageKey(for languageCode: String) -> String {
        let resolved = SupportedLanguage.legacyResolved(languageCode).rawValue
        return "\(storageKey).\(resolved)"
    }

    private func loadTable(languageCode: String) -> [String: FlashcardDailyStats] {
        let key = storageKey(for: languageCode)
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: FlashcardDailyStats].self, from: data)) ?? [:]
    }

    private func saveTable(_ table: [String: FlashcardDailyStats], languageCode: String) {
        guard let data = try? JSONEncoder().encode(table) else { return }
        defaults.set(data, forKey: storageKey(for: languageCode))
    }
}
