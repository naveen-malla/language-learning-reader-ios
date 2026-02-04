import Foundation

struct Transliterator {
    func pronounce(_ text: String) -> String {
        guard let latin = text.applyingTransform(.toLatin, reverse: false) else {
            return text
        }
        let stripped = latin.applyingTransform(.stripCombiningMarks, reverse: false) ?? latin
        return stripped.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
