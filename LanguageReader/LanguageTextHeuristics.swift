import Foundation

enum LanguageTextHeuristics {
    private static let germanStopwords: Set<String> = [
        "der", "die", "das", "und", "ist", "nicht", "ich", "du", "wir", "sie",
        "ein", "eine", "mit", "zu", "im", "den", "dem", "des", "auf", "für",
        "aber", "oder", "noch", "nur", "wie", "auch", "von", "bei", "als"
    ]

    private static let englishStopwords: Set<String> = [
        "the", "and", "is", "are", "to", "of", "in", "for", "with", "this",
        "that", "you", "we", "they", "a", "an", "on", "at", "from", "it"
    ]

    static func canonicalLanguageCode(_ value: String?) -> String {
        let trimmed = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !trimmed.isEmpty else { return "" }

        if let separator = trimmed.firstIndex(where: { $0 == "-" || $0 == "_" }) {
            return String(trimmed[..<separator])
        }

        return trimmed
    }

    static func containsKannadaScript(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0C80...0x0CFF).contains(Int(scalar.value))
        }
    }

    static func containsLatinAlphabet(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0041...0x005A).contains(Int(scalar.value)) || (0x0061...0x007A).contains(Int(scalar.value))
        }
    }

    static func looksLikeGerman(_ text: String) -> Bool {
        let normalized = text.lowercased()
        if normalized.contains("ä") || normalized.contains("ö") || normalized.contains("ü") || normalized.contains("ß") {
            return true
        }

        return countStopwordHits(in: normalized, stopwords: germanStopwords) >= 2
    }

    static func looksLikeEnglish(_ text: String) -> Bool {
        countStopwordHits(in: text.lowercased(), stopwords: englishStopwords) >= 2
    }

    static func isReadableEnglishTranslation(
        _ translated: String,
        source: String,
        sourceLanguage: String?
    ) -> Bool {
        let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceTrimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.caseInsensitiveCompare(sourceTrimmed) != .orderedSame else { return false }
        guard containsLatinAlphabet(in: trimmed) else { return false }

        switch canonicalLanguageCode(sourceLanguage) {
        case "kn":
            return !containsKannadaScript(in: trimmed)
        case "de":
            return !(looksLikeGerman(trimmed) && !looksLikeEnglish(trimmed))
        default:
            return true
        }
    }

    private static func countStopwordHits(in text: String, stopwords: Set<String>) -> Int {
        text
            .split(whereSeparator: { !$0.isLetter })
            .map { String($0) }
            .filter { stopwords.contains($0) }
            .count
    }
}
