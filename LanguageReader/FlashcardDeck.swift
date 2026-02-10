import Foundation

enum FlashcardDeck {
    static func reviewEntries(from entries: [VocabEntry]) -> [VocabEntry] {
        entries.filter { $0.status.isLearning }
    }
}
