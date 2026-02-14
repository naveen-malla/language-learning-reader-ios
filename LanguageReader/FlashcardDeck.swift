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

enum SpacedRepetitionAlgorithm: String, Codable, CaseIterable {
    case fsrs
    case sm2
}

struct SpacedRepetitionEngine: SpacedRepetitionScheduling {
    let algorithm: SpacedRepetitionAlgorithm
    let fsrsScheduler: FSRSScheduler
    let sm2Scheduler: SM2Scheduler

    init(
        algorithm: SpacedRepetitionAlgorithm = .fsrs,
        fsrsScheduler: FSRSScheduler = FSRSScheduler(),
        sm2Scheduler: SM2Scheduler = SM2Scheduler()
    ) {
        self.algorithm = algorithm
        self.fsrsScheduler = fsrsScheduler
        self.sm2Scheduler = sm2Scheduler
    }

    func previewInterval(for entry: VocabEntry, rating: ReviewRating) -> TimeInterval {
        switch algorithm {
        case .fsrs:
            return fsrsScheduler.previewInterval(for: entry, rating: rating)
        case .sm2:
            return sm2Scheduler.previewInterval(for: entry, rating: rating)
        }
    }

    func apply(rating: ReviewRating, to entry: VocabEntry, now: Date = Date()) {
        switch algorithm {
        case .fsrs:
            fsrsScheduler.apply(rating: rating, to: entry, now: now)
        case .sm2:
            sm2Scheduler.apply(rating: rating, to: entry, now: now)
        }
    }
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
        entry.srsStability = outcome.stability
        entry.srsDifficulty = outcome.difficulty
        entry.srsAlgorithm = outcome.algorithm.rawValue
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
                    lapseIncrement: 1,
                    stability: 0.2,
                    difficulty: inferredDifficulty(fromEase: max(1.3, currentEase - 0.20))
                )
            case .hard:
                return ReviewOutcome(
                    repetition: 0,
                    intervalDays: 0,
                    intervalSeconds: learningHardInterval,
                    easeFactor: max(1.3, currentEase - 0.15),
                    lapseIncrement: 0,
                    stability: 0.6,
                    difficulty: inferredDifficulty(fromEase: max(1.3, currentEase - 0.15))
                )
            case .good:
                return ReviewOutcome(
                    repetition: 1,
                    intervalDays: firstGraduatingIntervalDays,
                    intervalSeconds: firstGraduatingIntervalDays * Self.secondsPerDay,
                    easeFactor: currentEase,
                    lapseIncrement: 0,
                    stability: firstGraduatingIntervalDays,
                    difficulty: inferredDifficulty(fromEase: currentEase)
                )
            case .easy:
                return ReviewOutcome(
                    repetition: 2,
                    intervalDays: easyGraduatingIntervalDays,
                    intervalSeconds: easyGraduatingIntervalDays * Self.secondsPerDay,
                    easeFactor: max(1.3, currentEase + 0.05),
                    lapseIncrement: 0,
                    stability: easyGraduatingIntervalDays,
                    difficulty: inferredDifficulty(fromEase: max(1.3, currentEase + 0.05))
                )
            }
        }

        if rating == .again {
            return ReviewOutcome(
                repetition: 0,
                intervalDays: 0,
                intervalSeconds: learningAgainInterval,
                easeFactor: max(1.3, currentEase - 0.20),
                lapseIncrement: 1,
                stability: 0.2,
                difficulty: inferredDifficulty(fromEase: max(1.3, currentEase - 0.20))
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
            lapseIncrement: 0,
            stability: intervalDays,
            difficulty: inferredDifficulty(fromEase: ease)
        )
    }

    private func inferredDifficulty(fromEase easeFactor: Double) -> Double {
        let normalized = (max(1.3, easeFactor) - 1.3) / 1.7
        return min(10, max(1, 10 - normalized * 9))
    }
}

struct FSRSScheduler: SpacedRepetitionScheduling {
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    let relearnAgainInterval: TimeInterval
    let relearnHardInterval: TimeInterval
    let targetRetention: Double

    init(
        relearnAgainInterval: TimeInterval = 10 * 60,
        relearnHardInterval: TimeInterval = 30 * 60,
        targetRetention: Double = 0.90
    ) {
        self.relearnAgainInterval = relearnAgainInterval
        self.relearnHardInterval = relearnHardInterval
        self.targetRetention = min(0.97, max(0.80, targetRetention))
    }

    func previewInterval(for entry: VocabEntry, rating: ReviewRating) -> TimeInterval {
        nextOutcome(for: entry, rating: rating).intervalSeconds
    }

    func apply(rating: ReviewRating, to entry: VocabEntry, now: Date = Date()) {
        let outcome = nextOutcome(for: entry, rating: rating)
        let lapses = entry.srsLapseCount ?? 0

        entry.srsRepetition = outcome.repetition
        entry.srsIntervalDays = outcome.intervalDays
        entry.srsStability = outcome.stability
        entry.srsDifficulty = outcome.difficulty
        entry.srsAlgorithm = outcome.algorithm.rawValue
        entry.srsEaseFactor = inferredEaseFactor(fromDifficulty: outcome.difficulty)
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
        let repetition = entry.srsRepetition ?? 0
        let stability = max(0.2, entry.srsStability ?? entry.srsIntervalDays ?? 0.6)
        let difficulty = min(10, max(1, entry.srsDifficulty ?? 5.0))

        var nextDifficulty = difficulty + difficultyDelta(for: rating)
        nextDifficulty = min(10, max(1, nextDifficulty))

        if repetition == 0 {
            switch rating {
            case .again:
                return ReviewOutcome(
                    repetition: 0,
                    intervalDays: 0,
                    intervalSeconds: relearnAgainInterval,
                    easeFactor: inferredEaseFactor(fromDifficulty: nextDifficulty),
                    lapseIncrement: 1,
                    stability: 0.2,
                    difficulty: nextDifficulty,
                    algorithm: .fsrs
                )
            case .hard:
                return ReviewOutcome(
                    repetition: 0,
                    intervalDays: 0,
                    intervalSeconds: relearnHardInterval,
                    easeFactor: inferredEaseFactor(fromDifficulty: nextDifficulty),
                    lapseIncrement: 0,
                    stability: 0.6,
                    difficulty: nextDifficulty,
                    algorithm: .fsrs
                )
            case .good:
                let nextStability = 1.2
                let intervalDays = intervalDays(forStability: nextStability, multiplier: 1.0)
                return ReviewOutcome(
                    repetition: 1,
                    intervalDays: intervalDays,
                    intervalSeconds: intervalDays * Self.secondsPerDay,
                    easeFactor: inferredEaseFactor(fromDifficulty: nextDifficulty),
                    lapseIncrement: 0,
                    stability: nextStability,
                    difficulty: nextDifficulty,
                    algorithm: .fsrs
                )
            case .easy:
                let nextStability = 2.6
                let intervalDays = intervalDays(forStability: nextStability, multiplier: 1.15)
                return ReviewOutcome(
                    repetition: 2,
                    intervalDays: intervalDays,
                    intervalSeconds: intervalDays * Self.secondsPerDay,
                    easeFactor: inferredEaseFactor(fromDifficulty: nextDifficulty),
                    lapseIncrement: 0,
                    stability: nextStability,
                    difficulty: nextDifficulty,
                    algorithm: .fsrs
                )
            }
        }

        if rating == .again {
            let nextStability = max(0.2, stability * 0.45)
            return ReviewOutcome(
                repetition: 0,
                intervalDays: 0,
                intervalSeconds: relearnAgainInterval,
                easeFactor: inferredEaseFactor(fromDifficulty: nextDifficulty),
                lapseIncrement: 1,
                stability: nextStability,
                difficulty: nextDifficulty,
                algorithm: .fsrs
            )
        }

        let diffNorm = (nextDifficulty - 1) / 9
        let growth: Double
        let intervalMultiplier: Double
        switch rating {
        case .again:
            growth = 0.45
            intervalMultiplier = 0
        case .hard:
            growth = 1.12 - 0.12 * diffNorm
            intervalMultiplier = 0.75
        case .good:
            growth = 1.55 - 0.16 * diffNorm
            intervalMultiplier = 1.0
        case .easy:
            growth = 2.05 - 0.16 * diffNorm
            intervalMultiplier = 1.25
        }

        let nextStability = max(0.3, stability * growth)
        let intervalDays = intervalDays(forStability: nextStability, multiplier: intervalMultiplier)
        let nextRepetition = repetition + 1
        return ReviewOutcome(
            repetition: nextRepetition,
            intervalDays: intervalDays,
            intervalSeconds: intervalDays * Self.secondsPerDay,
            easeFactor: inferredEaseFactor(fromDifficulty: nextDifficulty),
            lapseIncrement: 0,
            stability: nextStability,
            difficulty: nextDifficulty,
            algorithm: .fsrs
        )
    }

    private func difficultyDelta(for rating: ReviewRating) -> Double {
        switch rating {
        case .again:
            return 0.35
        case .hard:
            return 0.16
        case .good:
            return -0.05
        case .easy:
            return -0.14
        }
    }

    private func intervalDays(forStability stability: Double, multiplier: Double) -> Double {
        let retentionFactor = max(0.85, targetRetention)
        let scaled = stability * multiplier * retentionFactor
        return max(1, ceil(scaled))
    }

    private func inferredEaseFactor(fromDifficulty difficulty: Double) -> Double {
        let normalized = (difficulty - 1) / 9
        return max(1.3, min(2.9, 2.8 - normalized * 1.4))
    }
}

private struct ReviewOutcome {
    let repetition: Int
    let intervalDays: Double
    let intervalSeconds: TimeInterval
    let easeFactor: Double
    let lapseIncrement: Int
    let stability: Double
    let difficulty: Double
    let algorithm: SpacedRepetitionAlgorithm

    init(
        repetition: Int,
        intervalDays: Double,
        intervalSeconds: TimeInterval,
        easeFactor: Double,
        lapseIncrement: Int,
        stability: Double? = nil,
        difficulty: Double? = nil,
        algorithm: SpacedRepetitionAlgorithm = .sm2
    ) {
        self.repetition = repetition
        self.intervalDays = intervalDays
        self.intervalSeconds = intervalSeconds
        self.easeFactor = easeFactor
        self.lapseIncrement = lapseIncrement
        self.stability = stability ?? max(0.2, intervalDays)
        self.difficulty = difficulty ?? 5
        self.algorithm = algorithm
    }
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
