import Foundation

/// Provides navigation logic for flashcard sequences.
struct FlashcardNavigator {
    /// Clamps an index to a valid range for the given count.
    /// - Parameters:
    ///   - index: The index to clamp.
    ///   - count: The total count of items.
    /// - Returns: A valid index within [0, count-1], or 0 if count is 0.
    static func clampedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    /// Returns the next index in a circular sequence.
    /// - Parameters:
    ///   - current: The current index.
    ///   - count: The total count of items.
    /// - Returns: The next index, wrapping to 0 after the last item.
    static func nextIndex(current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + 1) % count
    }
}
