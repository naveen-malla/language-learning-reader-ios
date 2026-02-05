import Foundation

final class DictionaryManager {
    static let shared = DictionaryManager()

    private let provider: DictionaryProvider
    private let normalizer = TextNormalizer()

    init(provider: DictionaryProvider? = nil) {
        if let provider {
            self.provider = provider
        } else {
            self.provider = DictionaryManager.makeProvider()
        }
    }

    func lookup(_ word: String) -> String? {
        let candidates = candidateKeys(for: word)
        for key in candidates {
            if let raw = provider.lookup(normalizedKey: key) {
                if let resolved = resolveMeaning(raw, for: key) {
                    return resolved
                }
            }
        }
        return nil
    }

    var sourceDescription: String {
        provider.sourceDescription
    }

    static func makeProvider() -> DictionaryProvider {
        if let url = DictionaryPaths.documentsDictionaryURL(),
           FileManager.default.fileExists(atPath: url.path),
           let sqliteProvider = SQLiteDictionaryProvider(fileURL: url, sourceDescription: "Local dictionary file") {
            return sqliteProvider
        }

        if let url = DictionaryPaths.bundledDictionaryURL(),
           FileManager.default.fileExists(atPath: url.path),
           let sqliteProvider = SQLiteDictionaryProvider(fileURL: url, sourceDescription: "Bundled dictionary file") {
            return sqliteProvider
        }

        return SampleDictionaryProvider()
    }

    private func candidateKeys(for word: String) -> [String] {
        let normalized = normalizer.normalize(word)
        var candidates: [String] = []

        func appendIfNew(_ value: String) {
            guard !value.isEmpty, !candidates.contains(value) else { return }
            candidates.append(value)
        }

        appendIfNew(stripEdgePunctuation(normalized))

        if let stripped = stripCommonKannadaSuffix(from: normalized) {
            appendIfNew(stripped)
        }

        return candidates
    }

    private func stripEdgePunctuation(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.punctuationCharacters)
    }

    private func stripCommonKannadaSuffix(from text: String) -> String? {
        let suffixes = [
            "ಗಳಲ್ಲಿ",
            "ಯಲ್ಲಿ",
            "ದಲ್ಲಿ",
            "ನಲ್ಲಿ",
            "ಗಳು",
            "ಗಳ",
            "ಕ್ಕೆ",
            "ನಿಗೆ",
            "ರಿಗೆ",
            "ಗೆ",
            "ದಿಂದ",
            "ನ್ನು",
            "ನು",
            "ಲಿ",
            "ಲ್ಲಿ"
        ]

        for suffix in suffixes {
            guard text.hasSuffix(suffix) else { continue }
            let base = String(text.dropLast(suffix.count))
            if base.count >= 2 {
                return base
            }
        }

        return nil
    }

    private func resolveMeaning(_ meaning: String, for key: String) -> String? {
        let trimmed = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=") {
            return resolveRedirect(trimmed, for: key)
        }

        return cleanMeaning(trimmed, for: key)
    }

    private func resolveRedirect(_ meaning: String, for key: String) -> String? {
        var redirect = meaning
        redirect.removeFirst()
        redirect = redirect.trimmingCharacters(in: .whitespacesAndNewlines)
        redirect = stripEdgePunctuation(redirect)
        redirect = stripTrailingDigits(redirect)

        let normalized = normalizer.normalize(redirect)
        guard !normalized.isEmpty, normalized != key else { return nil }

        if let redirectedMeaning = provider.lookup(normalizedKey: normalized) {
            return cleanMeaning(redirectedMeaning, for: normalized)
        }

        return nil
    }

    private func cleanMeaning(_ meaning: String, for key: String) -> String? {
        var cleaned = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasSuffix(".") {
            cleaned.removeLast()
        }

        if cleaned.isEmpty {
            return nil
        }

        if cleaned.lowercased() == key.lowercased() {
            return nil
        }

        return cleaned
    }

    private func stripTrailingDigits(_ text: String) -> String {
        var result = text
        while let last = result.unicodeScalars.last,
              CharacterSet.decimalDigits.contains(last) {
            result.removeLast()
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
