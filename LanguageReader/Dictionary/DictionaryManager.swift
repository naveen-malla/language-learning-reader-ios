import Foundation

final class DictionaryManager {
    static let shared = DictionaryManager()

    private let provider: DictionaryProvider
    private let normalizer = TextNormalizer()
    private let overrideStore: DictionaryOverrideStore

    init(provider: DictionaryProvider? = nil, overrideStore: DictionaryOverrideStore? = nil) {
        if let provider {
            self.provider = provider
        } else {
            self.provider = DictionaryManager.makeProvider()
        }
        self.overrideStore = overrideStore ?? DictionaryOverrideStore(
            fileURL: DictionaryPaths.documentsOverridesURL(),
            missingURL: DictionaryPaths.documentsMissingURL()
        )
    }

    func lookup(_ word: String) -> String? {
        lookupDetailed(word).meaning
    }

    func lookupDetailed(_ word: String) -> DictionaryLookupResult {
        let normalized = normalizer.normalize(word)
        if let overrideMeaning = overrideStore.lookup(normalizedKey: normalized) {
            return DictionaryLookupResult(
                word: word,
                normalizedKey: normalized,
                matchedKey: normalized,
                meaning: overrideMeaning,
                path: .override
            )
        }

        let candidates = candidateKeys(for: word)
        for key in candidates {
            if let raw = provider.lookup(normalizedKey: key) {
                if let resolved = resolveMeaning(raw, for: key) {
                    let basePath: DictionaryLookupResult.Path = (key == normalized) ? .direct : .suffix
                    let path = resolved.isRedirect ? .redirect : basePath
                    return DictionaryLookupResult(
                        word: word,
                        normalizedKey: normalized,
                        matchedKey: key,
                        meaning: resolved.meaning,
                        path: path
                    )
                }
            }
        }

        return DictionaryLookupResult(
            word: word,
            normalizedKey: normalized,
            matchedKey: nil,
            meaning: nil,
            path: .none
        )
    }

    var sourceDescription: String {
        provider.sourceDescription
    }

    func ensureOverridesFile() {
        overrideStore.ensureOverridesFile()
    }

    func setOverride(word: String, meaning: String) {
        overrideStore.setOverride(word: word, meaning: meaning)
    }

    func reportMissing(word: String) {
        overrideStore.appendMissing(word: word)
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

        for stripped in stripCommonKannadaSuffixes(from: normalized) {
            appendIfNew(stripped)
        }

        return candidates
    }

    private func stripEdgePunctuation(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.punctuationCharacters)
    }

    private func stripCommonKannadaSuffixes(from text: String) -> [String] {
        let suffixes = [
            "ಗಳಲ್ಲಿ",
            "ಯಲಿ",
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

        var results: [String] = []
        func appendIfValid(_ value: String) {
            guard value.count >= 2, !results.contains(value) else { return }
            results.append(value)
        }

        for suffix in suffixes {
            guard text.hasSuffix(suffix) else { continue }
            let base = String(text.dropLast(suffix.count))
            appendIfValid(base)

            // Some inflected forms retain a linking "ಯ" (e.g. ಮನೆಯಲಿ -> ಮನೆ).
            if base.hasSuffix("ಯ") {
                appendIfValid(String(base.dropLast()))
            }
        }

        return results
    }

    private func resolveMeaning(_ meaning: String, for key: String) -> (meaning: String, isRedirect: Bool)? {
        let trimmed = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=") {
            if let redirected = resolveRedirect(trimmed, for: key) {
                return (redirected, true)
            }
            return nil
        }

        if let cleaned = cleanMeaning(trimmed, for: key) {
            return (cleaned, false)
        }
        return nil
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

struct SentenceGlossToken: Identifiable {
    let id = UUID()
    let source: String
    let gloss: String?
    let isWord: Bool

    var rendered: String {
        gloss ?? source
    }

    var isGlossed: Bool {
        gloss != nil
    }
}

struct SentenceGlossResult {
    let source: String
    let tokens: [SentenceGlossToken]
    let wordCount: Int
    let glossedWordCount: Int

    var text: String {
        tokens.map(\.rendered).joined()
    }

    var coverage: Double {
        guard wordCount > 0 else { return 0 }
        return Double(glossedWordCount) / Double(wordCount)
    }
}

struct SentenceGlossTranslator {
    private let dictionaryManager: DictionaryManager
    private let tokenizer: Tokenizer

    init(dictionaryManager: DictionaryManager = .shared, tokenizer: Tokenizer = Tokenizer()) {
        self.dictionaryManager = dictionaryManager
        self.tokenizer = tokenizer
    }

    func gloss(_ sentence: String) -> SentenceGlossResult {
        let tokens = tokenizer.tokenize(sentence)
        var glossTokens: [SentenceGlossToken] = []
        glossTokens.reserveCapacity(tokens.count)

        var wordCount = 0
        var glossedWordCount = 0

        for token in tokens {
            if token.isWord {
                wordCount += 1
                if let meaning = dictionaryManager.lookup(token.text), !meaning.isEmpty {
                    glossedWordCount += 1
                    glossTokens.append(
                        SentenceGlossToken(source: token.text, gloss: meaning, isWord: true)
                    )
                } else {
                    glossTokens.append(
                        SentenceGlossToken(source: token.text, gloss: nil, isWord: true)
                    )
                }
            } else {
                glossTokens.append(
                    SentenceGlossToken(source: token.text, gloss: nil, isWord: false)
                )
            }
        }

        return SentenceGlossResult(
            source: sentence,
            tokens: glossTokens,
            wordCount: wordCount,
            glossedWordCount: glossedWordCount
        )
    }
}
