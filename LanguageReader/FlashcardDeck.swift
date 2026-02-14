import Foundation

enum ReviewRating: String, Codable, CaseIterable {
    case again
    case hard
    case good
    case easy

    var title: String {
        switch self {
        case .again:
            return "Again"
        case .hard:
            return "Hard"
        case .good:
            return "Good"
        case .easy:
            return "Easy"
        }
    }

    var sm2Quality: Int {
        switch self {
        case .again:
            return 1
        case .hard:
            return 3
        case .good:
            return 4
        case .easy:
            return 5
        }
    }
}

protocol SpacedRepetitionScheduling {
    func previewInterval(for entry: VocabEntry, rating: ReviewRating) -> TimeInterval
    func apply(rating: ReviewRating, to entry: VocabEntry, now: Date)
}

struct SM2Scheduler: SpacedRepetitionScheduling {
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    let learningAgainInterval: TimeInterval
    let learningHardInterval: TimeInterval
    let firstGraduatingIntervalDays: Double
    let easyGraduatingIntervalDays: Double

    init(
        learningAgainInterval: TimeInterval = 10 * 60,
        learningHardInterval: TimeInterval = 30 * 60,
        firstGraduatingIntervalDays: Double = 1,
        easyGraduatingIntervalDays: Double = 3
    ) {
        self.learningAgainInterval = learningAgainInterval
        self.learningHardInterval = learningHardInterval
        self.firstGraduatingIntervalDays = firstGraduatingIntervalDays
        self.easyGraduatingIntervalDays = easyGraduatingIntervalDays
    }

    func previewInterval(for entry: VocabEntry, rating: ReviewRating) -> TimeInterval {
        let repetition = entry.srsRepetition ?? 0
        if repetition == 0 {
            switch rating {
            case .again:
                return learningAgainInterval
            case .hard:
                return learningHardInterval
            case .good:
                return firstGraduatingIntervalDays * Self.secondsPerDay
            case .easy:
                return easyGraduatingIntervalDays * Self.secondsPerDay
            }
        }

        if rating == .again {
            return learningAgainInterval
        }

        let outcome = nextOutcome(for: entry, rating: rating)
        return outcome.intervalDays * Self.secondsPerDay
    }

    func apply(rating: ReviewRating, to entry: VocabEntry, now: Date = Date()) {
        let outcome = nextOutcome(for: entry, rating: rating)
        let lapses = entry.srsLapseCount ?? 0

        entry.srsEaseFactor = outcome.easeFactor
        entry.srsRepetition = outcome.repetition
        entry.srsIntervalDays = outcome.intervalDays
        entry.srsLapseCount = lapses + outcome.lapseIncrement
        entry.lastSeenAt = now
        entry.dueAt = now.addingTimeInterval(outcome.intervalSeconds)

        switch rating {
        case .again:
            entry.status = .level1
        case .hard:
            entry.status = entry.status.demoted()
        case .good:
            entry.status = entry.status.promoted()
        case .easy:
            entry.status = entry.status.promoted(by: 2)
        }
    }

    private func nextOutcome(for entry: VocabEntry, rating: ReviewRating) -> ReviewOutcome {
        let currentEase = max(1.3, entry.srsEaseFactor ?? 2.5)
        let repetition = entry.srsRepetition ?? 0
        let previousIntervalDays = entry.srsIntervalDays ?? 0

        if repetition == 0 {
            switch rating {
            case .again:
                return ReviewOutcome(
                    repetition: 0,
                    intervalDays: 0,
                    intervalSeconds: learningAgainInterval,
                    easeFactor: max(1.3, currentEase - 0.20),
                    lapseIncrement: 1
                )
            case .hard:
                return ReviewOutcome(
                    repetition: 0,
                    intervalDays: 0,
                    intervalSeconds: learningHardInterval,
                    easeFactor: max(1.3, currentEase - 0.15),
                    lapseIncrement: 0
                )
            case .good:
                return ReviewOutcome(
                    repetition: 1,
                    intervalDays: firstGraduatingIntervalDays,
                    intervalSeconds: firstGraduatingIntervalDays * Self.secondsPerDay,
                    easeFactor: currentEase,
                    lapseIncrement: 0
                )
            case .easy:
                return ReviewOutcome(
                    repetition: 2,
                    intervalDays: easyGraduatingIntervalDays,
                    intervalSeconds: easyGraduatingIntervalDays * Self.secondsPerDay,
                    easeFactor: max(1.3, currentEase + 0.05),
                    lapseIncrement: 0
                )
            }
        }

        if rating == .again {
            return ReviewOutcome(
                repetition: 0,
                intervalDays: 0,
                intervalSeconds: learningAgainInterval,
                easeFactor: max(1.3, currentEase - 0.20),
                lapseIncrement: 1
            )
        }

        let q = Double(rating.sm2Quality)
        var ease = currentEase + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        ease = max(1.3, ease)

        let nextRepetition = repetition + 1
        let previousInterval = max(previousIntervalDays, firstGraduatingIntervalDays)
        let baseInterval: Double
        if nextRepetition <= 1 {
            baseInterval = firstGraduatingIntervalDays
        } else if nextRepetition == 2 {
            baseInterval = 6
        } else {
            baseInterval = (previousInterval * ease).rounded(.toNearestOrAwayFromZero)
        }

        var intervalDays = max(1, baseInterval)
        if rating == .hard {
            intervalDays = max(1, floor(intervalDays * 0.80))
        } else if rating == .easy {
            intervalDays = max(intervalDays + 1, ceil(intervalDays * 1.25))
        }

        return ReviewOutcome(
            repetition: nextRepetition,
            intervalDays: intervalDays,
            intervalSeconds: intervalDays * Self.secondsPerDay,
            easeFactor: ease,
            lapseIncrement: 0
        )
    }
}

private struct ReviewOutcome {
    let repetition: Int
    let intervalDays: Double
    let intervalSeconds: TimeInterval
    let easeFactor: Double
    let lapseIncrement: Int
}

enum FlashcardDeck {
    static func reviewEntries(from entries: [VocabEntry], now: Date = Date()) -> [VocabEntry] {
        dueEntries(from: entries, now: now)
    }

    static func learningEntries(from entries: [VocabEntry]) -> [VocabEntry] {
        entries.filter { $0.status.isLearning && ($0.isSuspended != true) }
    }

    static func dueEntries(from entries: [VocabEntry], now: Date = Date(), limit: Int = 80) -> [VocabEntry] {
        let sorted = learningEntries(from: entries)
            .filter { isDue($0, now: now) }
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

    static func isDue(_ entry: VocabEntry, now: Date = Date()) -> Bool {
        guard entry.status.isLearning, entry.isSuspended != true else { return false }
        guard let dueAt = entry.dueAt else { return true }
        return dueAt <= now
    }

    static func nextDueDate(from entries: [VocabEntry], now: Date = Date()) -> Date? {
        learningEntries(from: entries)
            .compactMap(\.dueAt)
            .filter { $0 > now }
            .min()
    }

    static func sessionQueueIDs(from entries: [VocabEntry], now: Date = Date(), limit: Int = 40) -> [UUID] {
        Array(dueEntries(from: entries, now: now, limit: limit).map(\.id))
    }

    static func intervalLabel(for interval: TimeInterval) -> String {
        if interval < 60 * 60 {
            let minutes = max(1, Int(round(interval / 60)))
            return "\(minutes)m"
        }

        if interval < 24 * 60 * 60 {
            let hours = max(1, Int(round(interval / (60 * 60))))
            return "\(hours)h"
        }

        let days = max(1, Int(round(interval / (24 * 60 * 60))))
        return "\(days)d"
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

    func promoted(by steps: Int = 1) -> VocabStatus {
        guard steps > 0 else { return self }
        var current = self
        for _ in 0..<steps {
            switch current {
            case .level1:
                current = .level2
            case .level2:
                current = .level3
            case .level3:
                current = .level4
            case .level4, .known:
                current = .level4
            }
        }
        return current
    }
}
