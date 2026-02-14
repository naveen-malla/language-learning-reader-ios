import Foundation

final class DictionaryManager {
    static let shared = DictionaryManager()
    static let cloudFallbackEnabledKey = "dictionaryCloudFallbackEnabled"
    static let cloudFallbackTargetLanguageKey = "dictionaryCloudFallbackTargetLanguage"

    private let provider: DictionaryProvider
    private let normalizer = TextNormalizer()
    private let overrideStore: DictionaryOverrideStore
    private let cloudStore: DictionaryCloudMeaningStore
    private let remoteProvider: RemoteWordMeaningProviding?
    private let sourceLanguageProvider: () -> String
    private let targetLanguageProvider: () -> String
    private let defaults: UserDefaults

    init(
        provider: DictionaryProvider? = nil,
        overrideStore: DictionaryOverrideStore? = nil,
        cloudStore: DictionaryCloudMeaningStore? = nil,
        remoteProvider: RemoteWordMeaningProviding? = AzureRemoteWordMeaningProvider(),
        sourceLanguageProvider: (() -> String)? = nil,
        targetLanguageProvider: (() -> String)? = nil,
        defaults: UserDefaults = .standard
    ) {
        if let provider {
            self.provider = provider
        } else {
            self.provider = DictionaryManager.makeProvider()
        }
        self.overrideStore = overrideStore ?? DictionaryOverrideStore(
            fileURL: DictionaryPaths.documentsOverridesURL(),
            missingURL: DictionaryPaths.documentsMissingURL()
        )
        self.cloudStore = cloudStore ?? DictionaryCloudMeaningStore(
            fileURL: DictionaryPaths.documentsCloudCacheURL()
        )
        self.remoteProvider = remoteProvider
        self.defaults = defaults
        self.sourceLanguageProvider = sourceLanguageProvider ?? {
            TranslationSettingsStore(defaults: defaults).sourceLanguage
        }
        self.targetLanguageProvider = targetLanguageProvider ?? {
            TranslationSettingsStore(defaults: defaults).targetLanguage
        }
    }

    func lookup(_ word: String) -> String? {
        lookupDetailed(word).meaning
    }

    func lookupDetailed(_ word: String) -> DictionaryLookupResult {
        lookupDetailed(word, includeCloudCache: true)
    }

    func lookupDetailedWithRemoteFallback(_ word: String) async -> DictionaryLookupResult {
        let baseline = lookupDetailed(word, includeCloudCache: true)
        guard baseline.meaning == nil else {
            return baseline
        }

        let lookupWord = baseline.normalizedKey
        guard !lookupWord.isEmpty else {
            return baseline
        }

        guard isCloudFallbackEnabled, let remoteProvider else {
            return baseline
        }

        let sourceLanguage = activeSourceLanguageCode
        let targetLanguage = activeTargetLanguageCode

        guard
            let remoteMeaning = await remoteProvider.lookupMeaning(
                for: lookupWord,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        else {
            return baseline
        }

        guard let cleanedMeaning = cleanMeaning(remoteMeaning, for: baseline.normalizedKey) else {
            return baseline
        }

        cloudStore.setMeaning(
            normalizedKey: baseline.normalizedKey,
            languageCode: sourceLanguage,
            meaning: cleanedMeaning,
            source: "remote"
        )

        return DictionaryLookupResult(
            word: word,
            normalizedKey: baseline.normalizedKey,
            matchedKey: baseline.normalizedKey,
            meaning: cleanedMeaning,
            path: .remote
        )
    }

    func prefetchRemoteMeanings(for words: [String]) async {
        guard isCloudFallbackEnabled, remoteProvider != nil else {
            return
        }

        var seen: Set<String> = []
        for word in words {
            let normalized = normalizer.normalize(word)
            guard !normalized.isEmpty, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)

            let local = lookupDetailed(word, includeCloudCache: true)
            guard local.meaning == nil else {
                continue
            }

            _ = await lookupDetailedWithRemoteFallback(word)
        }
    }

    func cloudCacheCount() -> Int {
        cloudStore.allCount()
    }

    func clearCloudCache() {
        cloudStore.clear()
    }

    var isCloudFallbackEnabled: Bool {
        if defaults.object(forKey: Self.cloudFallbackEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: Self.cloudFallbackEnabledKey)
    }

    private var activeSourceLanguageCode: String {
        normalizeLanguageCode(sourceLanguageProvider())
    }

    private var activeTargetLanguageCode: String {
        let override = defaults.string(forKey: Self.cloudFallbackTargetLanguageKey)
        let raw = (override?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? (override ?? "")
            : targetLanguageProvider()
        let normalized = normalizeLanguageCode(raw)
        return normalized.isEmpty ? "en" : normalized
    }

    private func lookupDetailed(_ word: String, includeCloudCache: Bool) -> DictionaryLookupResult {
        let normalized = normalizer.normalize(word)
        let languageCode = activeSourceLanguageCode
        guard !normalized.isEmpty else {
            return DictionaryLookupResult(
                word: word,
                normalizedKey: normalized,
                matchedKey: nil,
                meaning: nil,
                path: .none
            )
        }

        if let overrideMeaning = overrideStore.lookup(normalizedKey: normalized) {
            return DictionaryLookupResult(
                word: word,
                normalizedKey: normalized,
                matchedKey: normalized,
                meaning: overrideMeaning,
                path: .override
            )
        }

        let candidates = candidateKeys(for: word, languageCode: languageCode)
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

        if includeCloudCache,
           let cachedMeaning = cloudStore.lookup(normalizedKey: normalized, languageCode: languageCode) {
            return DictionaryLookupResult(
                word: word,
                normalizedKey: normalized,
                matchedKey: normalized,
                meaning: cachedMeaning,
                path: .cache
            )
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

    private func candidateKeys(for word: String, languageCode: String) -> [String] {
        let normalized = normalizer.normalize(word)
        let stripped = stripEdgePunctuation(normalized)
        let profile = DictionaryLanguageProfile.resolve(for: languageCode)
        let generator = DictionaryWordFormGenerator(profile: profile)
        var candidates: [String] = []

        func appendIfNew(_ value: String) {
            guard !value.isEmpty, !candidates.contains(value) else { return }
            candidates.append(value)
        }

        appendIfNew(normalized)
        appendIfNew(stripped)
        for candidate in generator.candidateKeys(from: stripped) {
            appendIfNew(candidate)
        }

        return candidates
    }

    private func stripEdgePunctuation(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.punctuationCharacters)
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
        cleaned = conciseMeaning(from: cleaned)

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

    private func conciseMeaning(from meaning: String) -> String {
        var value = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }

        if value.hasPrefix("=") {
            return value
        }

        value = stripLeadingMetadata(from: value)

        if let range = value.range(of: " - a)", options: [.caseInsensitive]) {
            let candidate = value[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                value = candidate
            }
        }

        if let semicolonIndex = value.firstIndex(of: ";") {
            let candidate = value[..<semicolonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                value = candidate
            }
        }

        if value.count > 140, let commaIndex = value.firstIndex(of: ",") {
            let candidate = value[..<commaIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.count >= 10 {
                value = candidate
            }
        }

        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        while let last = value.last {
            switch last {
            case ".", ";", ",", ":":
                value.removeLast()
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                return value
            }
        }

        return value
    }

    private func stripLeadingMetadata(from text: String) -> String {
        let patterns = [
            #"^\s*\([^)]*\)\s*"#,
            #"^\s*\[[^\]]*\]\s*"#,
            #"^\s*\d+\.\s*"#
        ]

        var value = text
        var madeProgress = true
        while madeProgress {
            madeProgress = false
            for pattern in patterns {
                if let range = value.range(of: pattern, options: .regularExpression) {
                    value.removeSubrange(range)
                    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    madeProgress = true
                }
            }
        }

        return value
    }

    private func normalizeLanguageCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
