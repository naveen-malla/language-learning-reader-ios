import Foundation

/// Normalizes text for consistent dictionary lookups and comparisons.
struct TextNormalizer {
    /// Normalizes text by trimming whitespace and converting to lowercase.
    /// - Parameter text: The text to normalize.
    /// - Returns: Normalized text suitable for dictionary keys.
    func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
