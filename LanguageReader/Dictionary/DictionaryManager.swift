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

    func evaluateQuality(
        fixture: DictionaryQualityFixture? = nil,
        tokenizer: Tokenizer = Tokenizer()
    ) -> DictionaryQualitySnapshot {
        let selection = resolveQualityFixtureSelection(fixture)
        let requestedLanguageCode = selection.requestedLanguageCode
        let selectedFixture = selection.fixture
        let usedFallbackFixture = selection.usedFallbackFixture

        var tokenTotal = 0
        var tokenHits = 0
        var uniqueWords: Set<String> = []
        var uniqueHitWords: Set<String> = []
        var unresolvedByWord: [String: Int] = [:]

        for sentence in selectedFixture.corpusSentences {
            for token in tokenizer.tokenize(sentence) where token.isWord {
                let normalized = normalizer.normalize(token.text)
                guard !normalized.isEmpty else { continue }

                tokenTotal += 1
                uniqueWords.insert(normalized)

                let lookup = lookupDetailed(
                    token.text,
                    includeCloudCache: true,
                    languageCodeOverride: selectedFixture.languageCode
                )
                if let meaning = lookup.meaning, !meaning.isEmpty {
                    tokenHits += 1
                    uniqueHitWords.insert(normalized)
                } else {
                    unresolvedByWord[normalized, default: 0] += 1
                }
            }
        }

        let uniqueTotal = uniqueWords.count
        let uniqueHits = uniqueHitWords.count

        var goldHits = 0
        var goldCorrect = 0
        let goldTotal = selectedFixture.goldEntries.count

        for goldEntry in selectedFixture.goldEntries {
            let lookup = lookupDetailed(
                goldEntry.word,
                includeCloudCache: true,
                languageCodeOverride: selectedFixture.languageCode
            )
            guard let meaning = lookup.meaning, !meaning.isEmpty else {
                continue
            }
            goldHits += 1
            if goldEntry.matches(actualMeaning: meaning) {
                goldCorrect += 1
            }
        }

        let tokenCoverage = ratio(tokenHits, tokenTotal)
        let uniqueCoverage = ratio(uniqueHits, uniqueTotal)
        let goldHitRate = ratio(goldHits, goldTotal)
        let goldAccuracy = ratio(goldCorrect, goldTotal)

        let thresholdChecks = [
            DictionaryQualityThresholdCheck(
                metricName: "Token Coverage",
                actual: tokenCoverage,
                expectedMinimum: selectedFixture.thresholds.tokenCoverageMinimum
            ),
            DictionaryQualityThresholdCheck(
                metricName: "Unique Coverage",
                actual: uniqueCoverage,
                expectedMinimum: selectedFixture.thresholds.uniqueCoverageMinimum
            ),
            DictionaryQualityThresholdCheck(
                metricName: "Gold Hit Rate",
                actual: goldHitRate,
                expectedMinimum: selectedFixture.thresholds.goldHitRateMinimum
            ),
            DictionaryQualityThresholdCheck(
                metricName: "Gold Accuracy",
                actual: goldAccuracy,
                expectedMinimum: selectedFixture.thresholds.goldAccuracyMinimum
            )
        ]

        let unresolvedTop = unresolvedByWord
            .map { DictionaryQualityWordCount(word: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.word < rhs.word
            }
            .prefix(8)

        return DictionaryQualitySnapshot(
            fixtureName: selectedFixture.name,
            requestedLanguageCode: requestedLanguageCode,
            fixtureLanguageCode: selectedFixture.languageCode,
            usedFallbackFixture: usedFallbackFixture,
            tokenCoverage: tokenCoverage,
            tokenHits: tokenHits,
            tokenTotal: tokenTotal,
            uniqueCoverage: uniqueCoverage,
            uniqueHits: uniqueHits,
            uniqueTotal: uniqueTotal,
            goldHitRate: goldHitRate,
            goldHits: goldHits,
            goldTotal: goldTotal,
            goldAccuracy: goldAccuracy,
            goldCorrect: goldCorrect,
            thresholdChecks: thresholdChecks,
            unresolvedTop: Array(unresolvedTop)
        )
    }

    func evaluateQualityWithRemoteEnrichment(
        fixture: DictionaryQualityFixture? = nil,
        tokenizer: Tokenizer = Tokenizer()
    ) async -> DictionaryQualitySnapshot {
        let selection = resolveQualityFixtureSelection(fixture)
        let selectedFixture = selection.fixture

        let sourceLanguage = normalizeLanguageCode(selectedFixture.languageCode)
        if isCloudFallbackEnabled && sourceLanguage == activeSourceLanguageCode {
            let corpusWords = collectUniqueWords(
                from: selectedFixture.corpusSentences,
                tokenizer: tokenizer
            )
            let goldWords = collectUniqueWords(
                from: selectedFixture.goldEntries.map(\.word),
                tokenizer: tokenizer
            )
            let allWords = Set(corpusWords).union(goldWords)
            if !allWords.isEmpty {
                await prefetchRemoteMeanings(for: Array(allWords))
            }
        }

        return evaluateQuality(fixture: selectedFixture, tokenizer: tokenizer)
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

    private func resolveQualityFixtureSelection(
        _ fixture: DictionaryQualityFixture?
    ) -> (requestedLanguageCode: String, fixture: DictionaryQualityFixture, usedFallbackFixture: Bool) {
        if let fixture {
            return (fixture.languageCode, fixture, false)
        }

        let requestedLanguageCode = activeSourceLanguageCode
        let selection = DictionaryQualityFixture.select(for: requestedLanguageCode)
        return (requestedLanguageCode, selection.fixture, selection.usedFallbackFixture)
    }

    private func collectUniqueWords(
        from sentences: [String],
        tokenizer: Tokenizer
    ) -> [String] {
        var unique: Set<String> = []
        for sentence in sentences {
            for token in tokenizer.tokenize(sentence) where token.isWord {
                let normalized = normalizer.normalize(token.text)
                guard !normalized.isEmpty else { continue }
                unique.insert(normalized)
            }
        }
        return Array(unique)
    }

    private func lookupDetailed(
        _ word: String,
        includeCloudCache: Bool,
        languageCodeOverride: String? = nil
    ) -> DictionaryLookupResult {
        let normalized = normalizer.normalize(word)
        let overrideLanguage = languageCodeOverride.map(normalizeLanguageCode) ?? ""
        let languageCode = overrideLanguage.isEmpty ? activeSourceLanguageCode : overrideLanguage
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

    private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }
}

struct DictionaryQualitySnapshot {
    let fixtureName: String
    let requestedLanguageCode: String
    let fixtureLanguageCode: String
    let usedFallbackFixture: Bool
    let tokenCoverage: Double
    let tokenHits: Int
    let tokenTotal: Int
    let uniqueCoverage: Double
    let uniqueHits: Int
    let uniqueTotal: Int
    let goldHitRate: Double
    let goldHits: Int
    let goldTotal: Int
    let goldAccuracy: Double
    let goldCorrect: Int
    let thresholdChecks: [DictionaryQualityThresholdCheck]
    let unresolvedTop: [DictionaryQualityWordCount]

    var thresholdPassed: Bool {
        thresholdChecks.allSatisfy(\.passed)
    }
}

struct DictionaryQualityWordCount: Hashable {
    let word: String
    let count: Int
}

struct DictionaryQualityThresholdCheck: Hashable {
    let metricName: String
    let actual: Double
    let expectedMinimum: Double

    var passed: Bool {
        actual >= expectedMinimum
    }
}

struct DictionaryQualityThresholds {
    let tokenCoverageMinimum: Double
    let uniqueCoverageMinimum: Double
    let goldHitRateMinimum: Double
    let goldAccuracyMinimum: Double

    init(
        tokenCoverageMinimum: Double,
        uniqueCoverageMinimum: Double,
        goldHitRateMinimum: Double,
        goldAccuracyMinimum: Double
    ) {
        self.tokenCoverageMinimum = tokenCoverageMinimum
        self.uniqueCoverageMinimum = uniqueCoverageMinimum
        self.goldHitRateMinimum = goldHitRateMinimum
        self.goldAccuracyMinimum = goldAccuracyMinimum
    }
}

enum DictionaryQualityMatchMode {
    case contains
    case exact
}

struct DictionaryQualityGoldEntry {
    let word: String
    let acceptedMeanings: [String]
    let matchMode: DictionaryQualityMatchMode

    init(word: String, acceptedMeanings: [String], matchMode: DictionaryQualityMatchMode = .contains) {
        self.word = word
        self.acceptedMeanings = acceptedMeanings
        self.matchMode = matchMode
    }

    func matches(actualMeaning: String) -> Bool {
        let actual = actualMeaning.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !actual.isEmpty else { return false }

        for accepted in acceptedMeanings {
            let expected = accepted.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !expected.isEmpty else { continue }

            switch matchMode {
            case .contains:
                if actual.contains(expected) { return true }
            case .exact:
                if actual == expected { return true }
            }
        }

        return false
    }
}

struct DictionaryQualityFixture {
    let name: String
    let languageCode: String
    let corpusSentences: [String]
    let goldEntries: [DictionaryQualityGoldEntry]
    let thresholds: DictionaryQualityThresholds

    init(
        name: String,
        languageCode: String,
        corpusSentences: [String],
        goldEntries: [DictionaryQualityGoldEntry],
        thresholds: DictionaryQualityThresholds
    ) {
        self.name = name
        self.languageCode = languageCode
        self.corpusSentences = corpusSentences
        self.goldEntries = goldEntries
        self.thresholds = thresholds
    }

    static func select(for languageCode: String) -> (fixture: DictionaryQualityFixture, usedFallbackFixture: Bool) {
        let canonical = canonicalLanguageCode(languageCode)
        if let exact = fixturesByLanguage[canonical] {
            return (exact, false)
        }
        return (englishCoreV1, true)
    }

    private static var fixturesByLanguage: [String: DictionaryQualityFixture] {
        [
            "kn": .kannadaCoreV1,
            "en": .englishCoreV1
        ]
    }

    private static func canonicalLanguageCode(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }

        if let separator = trimmed.firstIndex(where: { $0 == "-" || $0 == "_" }) {
            return String(trimmed[..<separator])
        }

        return trimmed
    }

    static let kannadaCoreV1 = DictionaryQualityFixture(
        name: "Kannada Core V1",
        languageCode: "kn",
        corpusSentences: [
            "ನಮಸ್ಕಾರ, ಇದು ನನ್ನ ಮನೆ.",
            "ಅವನು ಪುಸ್ತಕವನ್ನು ಓದುತ್ತಿದ್ದ.",
            "ನಾನು ಶಾಲೆಗೆ ಹೋಗುತ್ತೇನೆ.",
            "ಅವರು ಆಹಾರವನ್ನು ತಿನ್ನುತ್ತಿದ್ದರು.",
            "ನೀರು ಸ್ವಚ್ಛವಾಗಿದೆ.",
            "ಇದು ಒಂದು ಸುಂದರ ಕಥೆ.",
            "ಮಗನು ಕಿಟಕಿಯನ್ನು ತೆರೆದನು.",
            "ಅವಳು ಪತ್ರವನ್ನು ಬರೆದಳು.",
            "ಬೆಳಿಗ್ಗೆ ನಾವು ಮಾರುಕಟ್ಟೆಗೆ ಹೋಗಿದ್ದೆವು.",
            "ಭಾಷೆ ಕಲಿಯುವುದು ಸಮಯ ತೆಗೆದುಕೊಳ್ಳುತ್ತದೆ."
        ],
        goldEntries: [
            .init(word: "ನಮಸ್ಕಾರ", acceptedMeanings: ["hello", "greeting"]),
            .init(word: "ಮನೆ", acceptedMeanings: ["house", "home"]),
            .init(word: "ಪುಸ್ತಕ", acceptedMeanings: ["book"]),
            .init(word: "ಶಾಲೆ", acceptedMeanings: ["school"]),
            .init(word: "ಆಹಾರ", acceptedMeanings: ["food"]),
            .init(word: "ನೀರು", acceptedMeanings: ["water"]),
            .init(word: "ಕಥೆ", acceptedMeanings: ["story"]),
            .init(word: "ಭಾಷೆ", acceptedMeanings: ["language"]),
            .init(word: "ಕಿಟಕಿ", acceptedMeanings: ["window"]),
            .init(word: "ಪತ್ರ", acceptedMeanings: ["letter"]),
            .init(word: "ಮಾರುಕಟ್ಟೆ", acceptedMeanings: ["market"])
        ],
        thresholds: DictionaryQualityThresholds(
            tokenCoverageMinimum: 0.70,
            uniqueCoverageMinimum: 0.60,
            goldHitRateMinimum: 0.80,
            goldAccuracyMinimum: 0.60
        )
    )

    static let englishCoreV1 = DictionaryQualityFixture(
        name: "English Core V1",
        languageCode: "en",
        corpusSentences: [
            "Hello, this is my house.",
            "He reads a book every day.",
            "I go to school in the morning.",
            "They ate food together.",
            "Water is clean.",
            "This is a short story.",
            "The child opened the window.",
            "She wrote a letter.",
            "We went to the market in the morning.",
            "Learning a language takes time."
        ],
        goldEntries: [
            .init(word: "hello", acceptedMeanings: ["hello", "greeting"]),
            .init(word: "house", acceptedMeanings: ["house", "home"]),
            .init(word: "book", acceptedMeanings: ["book"]),
            .init(word: "school", acceptedMeanings: ["school"]),
            .init(word: "food", acceptedMeanings: ["food"]),
            .init(word: "water", acceptedMeanings: ["water"]),
            .init(word: "story", acceptedMeanings: ["story"]),
            .init(word: "language", acceptedMeanings: ["language"]),
            .init(word: "window", acceptedMeanings: ["window"]),
            .init(word: "letter", acceptedMeanings: ["letter"]),
            .init(word: "market", acceptedMeanings: ["market"])
        ],
        thresholds: DictionaryQualityThresholds(
            tokenCoverageMinimum: 0.70,
            uniqueCoverageMinimum: 0.60,
            goldHitRateMinimum: 0.80,
            goldAccuracyMinimum: 0.60
        )
    )
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
