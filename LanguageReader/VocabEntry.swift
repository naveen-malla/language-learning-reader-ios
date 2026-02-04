import Foundation
import SwiftData

/// Represents the learning status of a vocabulary word.
enum VocabStatus: String, Codable, CaseIterable {
    case new
    case learning
    case known

    /// Human-readable display name for the status.
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

    /// Color name for UI representation.
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

    /// Returns the next status in the learning cycle.
    var next: VocabStatus {
        switch self {
        case .new:
            return .learning
        case .learning:
            return .known
        case .known:
            return .new
        }
    }
}

/// Represents a vocabulary entry in the user's personal dictionary.
@Model
final class VocabEntry {
    /// Unique identifier for this entry.
    @Attribute(.unique) var id: UUID
    
    /// Normalized key used for lookups (lowercase, trimmed).
    /// This ensures each unique word form appears only once.
    @Attribute(.unique) var normalizedKey: String
    
    /// The original word text as encountered.
    var word: String
    
    /// The meaning or translation of the word.
    var meaning: String
    
    /// Current learning status of the word.
    var status: VocabStatus
    
    /// When this entry was first created.
    var createdAt: Date
    
    /// When this word was last encountered or reviewed.
    var lastSeenAt: Date
    
    /// Number of times this word has been encountered.
    var encounterCount: Int

    /// Creates a new vocabulary entry.
    /// - Parameters:
    ///   - word: The original word text.
    ///   - normalizedKey: Normalized form for unique identification.
    ///   - meaning: The word's meaning or translation.
    ///   - status: Initial learning status (defaults to .new).
    ///   - createdAt: Creation timestamp (defaults to now).
    ///   - lastSeenAt: Last seen timestamp (defaults to now).
    ///   - encounterCount: Initial encounter count (defaults to 1).
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
