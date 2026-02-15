import Foundation
import SwiftData

enum VocabStatus: String, Codable, CaseIterable {
    case level1
    case level2
    case level3
    case level4
    case known

    var displayName: String {
        switch self {
        case .level1:
            return "Level 1"
        case .level2:
            return "Level 2"
        case .level3:
            return "Level 3"
        case .level4:
            return "Level 4"
        case .known:
            return "Known"
        }
    }

    var shortLabel: String {
        switch self {
        case .level1:
            return "1"
        case .level2:
            return "2"
        case .level3:
            return "3"
        case .level4:
            return "4"
        case .known:
            return "Known"
        }
    }

    var meaningLabel: String {
        switch self {
        case .level1:
            return "Just added, review often."
        case .level2:
            return "Recognize in context with light effort."
        case .level3:
            return "Mostly familiar, occasional review."
        case .level4:
            return "Confident recall, rare review."
        case .known:
            return "Fully known, hide from practice lists."
        }
    }

    var levelBadgeLabel: String {
        shortLabel
    }

    var colorName: String {
        switch self {
        case .level1, .level2, .level3, .level4:
            return "green"
        case .known:
            return "gray"
        }
    }

    var next: VocabStatus {
        switch self {
        case .level1:
            return .level2
        case .level2:
            return .level3
        case .level3:
            return .level4
        case .level4:
            return .known
        case .known:
            return .level1
        }
    }

    var isKnown: Bool {
        self == .known
    }

    var isLearning: Bool {
        self != .known
    }

    static let learningLevels: [VocabStatus] = [.level1, .level2, .level3, .level4]
    static let progression: [VocabStatus] = [.level1, .level2, .level3, .level4, .known]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "new":
            self = .level1
        case "learning":
            self = .level2
        case "known":
            self = .known
        case VocabStatus.level1.rawValue:
            self = .level1
        case VocabStatus.level2.rawValue:
            self = .level2
        case VocabStatus.level3.rawValue:
            self = .level3
        case VocabStatus.level4.rawValue:
            self = .level4
        case VocabStatus.known.rawValue:
            self = .known
        default:
            self = .level1
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

@Model
final class VocabEntry {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var normalizedKey: String
    var word: String
    var meaning: String
    var status: VocabStatus
    var createdAt: Date
    var lastSeenAt: Date
    var encounterCount: Int
    var dueAt: Date?
    var srsIntervalDays: Double?
    var srsEaseFactor: Double?
    var srsRepetition: Int?
    var srsLapseCount: Int?
    var isSuspended: Bool?
    var srsStability: Double?
    var srsDifficulty: Double?
    var srsAlgorithm: String?

    init(
        word: String,
        normalizedKey: String,
        meaning: String,
        status: VocabStatus = .level1,
        createdAt: Date = Date(),
        lastSeenAt: Date = Date(),
        encounterCount: Int = 1,
        dueAt: Date? = nil,
        srsIntervalDays: Double = 0,
        srsEaseFactor: Double = 2.5,
        srsRepetition: Int = 0,
        srsLapseCount: Int = 0,
        isSuspended: Bool = false,
        srsStability: Double? = nil,
        srsDifficulty: Double? = nil,
        srsAlgorithm: String? = nil
    ) {
        self.id = UUID()
        self.word = word
        self.normalizedKey = normalizedKey
        self.meaning = meaning
        self.status = status
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.encounterCount = encounterCount
        self.dueAt = dueAt
        self.srsIntervalDays = srsIntervalDays
        self.srsEaseFactor = srsEaseFactor
        self.srsRepetition = srsRepetition
        self.srsLapseCount = srsLapseCount
        self.isSuspended = isSuspended
        self.srsStability = srsStability
        self.srsDifficulty = srsDifficulty
        self.srsAlgorithm = srsAlgorithm
    }
}
