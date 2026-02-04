import Foundation

/// Converts text from non-Latin scripts to Latin transliteration.
struct Transliterator {
    /// Converts text to a Latin pronunciation guide.
    /// - Parameter text: The text to transliterate.
    /// - Returns: Latin transliteration suitable for pronunciation.
    func pronounce(_ text: String) -> String {
        guard let latin = text.applyingTransform(.toLatin, reverse: false) else {
            return text
        }
        let stripped = latin.applyingTransform(.stripCombiningMarks, reverse: false) ?? latin
        return stripped.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
