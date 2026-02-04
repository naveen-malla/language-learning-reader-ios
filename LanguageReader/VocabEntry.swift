import Foundation
import SwiftData

enum VocabStatus: String, Codable, CaseIterable {
    case new
    case learning
    case known

    var displayName: String {
        switch self {
        case .new:
            return "New"
        case .learning:
            return "Learning"
        case .known:
            return "Known"
        }
    }

    var colorName: String {
        switch self {
        case .new:
            return "blue"
        case .learning:
            return "yellow"
        case .known:
            return "gray"
        }
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

    init(
        word: String,
        normalizedKey: String,
        meaning: String,
        status: VocabStatus = .new,
        createdAt: Date = Date(),
        lastSeenAt: Date = Date(),
        encounterCount: Int = 1
    ) {
        self.id = UUID()
        self.word = word
        self.normalizedKey = normalizedKey
        self.meaning = meaning
        self.status = status
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.encounterCount = encounterCount
    }
}
