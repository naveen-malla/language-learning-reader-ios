import Foundation

enum FlashcardDirection: String, Codable, CaseIterable {
    case wordToMeaning
    case meaningToWord
}

enum FlashcardBinaryAnswer: String, Codable, CaseIterable {
    case correct
    case wrong
}

struct FlashcardPrompt: Hashable, Identifiable {
    let entryID: UUID
    let direction: FlashcardDirection

    var id: String {
        "\(entryID.uuidString)-\(direction.rawValue)"
    }
}

struct FlashcardRoundOutcome {
    let status: VocabStatus
    let nextConsecutiveSuccessRounds: Int
    let shouldRequeue: Bool
}

enum FlashcardSettings {
    static let sessionWordLimitKey = "flashcards_session_word_limit"
    static let sessionWordLimitOptions = [5, 10, 15, 20, 30]

    static func normalizedSessionWordLimit(_ value: Int) -> Int {
        guard sessionWordLimitOptions.contains(value) else {
            return FlashcardDeck.defaultSessionWordLimit
        }
        return value
    }
}

enum SimpleLevelScheduler {
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    static func intervalDays(for status: VocabStatus) -> Int? {
        switch status {
        case .level1:
            return 1
        case .level2:
            return 3
        case .level3:
            return 7
        case .level4:
            return 15
        case .known:
            return nil
        }
    }

    static func dueDate(for status: VocabStatus, baseDate: Date) -> Date? {
        guard let intervalDays = intervalDays(for: status) else { return nil }
        return baseDate.addingTimeInterval(TimeInterval(intervalDays) * secondsPerDay)
    }

    static func nextDueDate(for status: VocabStatus, now: Date = Date()) -> Date? {
        dueDate(for: status, baseDate: now)
    }

    static func isDue(_ entry: VocabEntry, now: Date = Date()) -> Bool {
        guard entry.status.isLearning, entry.isSuspended != true else { return false }
        guard let dueAt = entry.dueAt else { return true }
        return dueAt <= now
    }
}

enum FlashcardRoundEvaluator {
    static func evaluate(
        status: VocabStatus,
        consecutiveSuccessRounds: Int,
        answers: [FlashcardBinaryAnswer]
    ) -> FlashcardRoundOutcome {
        precondition(answers.count == 2, "A round must include two directional answers")

        let correctCount = answers.filter { $0 == .correct }.count

        switch correctCount {
        case 2:
            var nextStreak = max(0, consecutiveSuccessRounds) + 1
            var nextStatus = status
            if nextStreak >= 2 {
                nextStatus = status.promoted()
                nextStreak = 0
            }
            return FlashcardRoundOutcome(
                status: nextStatus,
                nextConsecutiveSuccessRounds: nextStreak,
                shouldRequeue: false
            )

        case 1:
            return FlashcardRoundOutcome(
                status: status,
                nextConsecutiveSuccessRounds: 0,
                shouldRequeue: true
            )

        default:
            return FlashcardRoundOutcome(
                status: status.demoted(),
                nextConsecutiveSuccessRounds: 0,
                shouldRequeue: true
            )
        }
    }
}

enum FlashcardDeck {
    static let defaultSessionWordLimit = 5

    static func prompts(for entryID: UUID) -> [FlashcardPrompt] {
        [
            FlashcardPrompt(entryID: entryID, direction: .wordToMeaning),
            FlashcardPrompt(entryID: entryID, direction: .meaningToWord)
        ]
    }

    static func learningEntries(from entries: [VocabEntry]) -> [VocabEntry] {
        entries.filter { $0.status.isLearning && ($0.isSuspended != true) }
    }

    static func dueEntries(from entries: [VocabEntry], now: Date = Date(), limit: Int = 80) -> [VocabEntry] {
        let sorted = learningEntries(from: entries)
            .filter { SimpleLevelScheduler.isDue($0, now: now) }
            .sorted { lhs, rhs in
                let lhsDue = lhs.dueAt ?? .distantPast
                let rhsDue = rhs.dueAt ?? .distantPast
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                if lhs.lastSeenAt != rhs.lastSeenAt {
                    return lhs.lastSeenAt < rhs.lastSeenAt
                }
                return lhs.createdAt < rhs.createdAt
            }

        return Array(sorted.prefix(limit))
    }

    static func nextDueDate(from entries: [VocabEntry], now: Date = Date()) -> Date? {
        learningEntries(from: entries)
            .compactMap(\.dueAt)
            .filter { $0 > now }
            .min()
    }

    static func sessionPrompts(
        from entries: [VocabEntry],
        now: Date = Date(),
        limit: Int = defaultSessionWordLimit
    ) -> [FlashcardPrompt] {
        dueEntries(from: entries, now: now, limit: limit)
            .flatMap { prompts(for: $0.id) }
    }

    static func plannedSessionWordCount(
        from entries: [VocabEntry],
        now: Date = Date(),
        limit: Int = defaultSessionWordLimit
    ) -> Int {
        dueEntries(from: entries, now: now, limit: limit).count
    }
}

private extension VocabStatus {
    func demoted() -> VocabStatus {
        switch self {
        case .level1:
            return .level1
        case .level2:
            return .level1
        case .level3:
            return .level2
        case .level4:
            return .level3
        case .known:
            return .level4
        }
    }

    func promoted() -> VocabStatus {
        switch self {
        case .level1:
            return .level2
        case .level2:
            return .level3
        case .level3:
            return .level4
        case .level4, .known:
            return .level4
        }
    }
}
