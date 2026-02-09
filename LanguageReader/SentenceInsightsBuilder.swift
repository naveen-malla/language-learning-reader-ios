import Foundation

struct SentenceWordInsight: Identifiable, Hashable {
    let id: String
    let word: String
    let normalizedKey: String
    let meaning: String?
    let pronunciation: String
}

struct SentenceInsights {
    let sentence: String
    let words: [SentenceWordInsight]
}

struct SentenceInsightsBuilder {
    private let tokenizer: Tokenizer
    private let dictionaryManager: DictionaryManager
    private let normalizer: TextNormalizer
    private let transliterator: Transliterator

    init(
        tokenizer: Tokenizer = Tokenizer(),
        dictionaryManager: DictionaryManager = .shared,
        normalizer: TextNormalizer = TextNormalizer(),
        transliterator: Transliterator = Transliterator()
    ) {
        self.tokenizer = tokenizer
        self.dictionaryManager = dictionaryManager
        self.normalizer = normalizer
        self.transliterator = transliterator
    }

    func build(for sentence: String) -> SentenceInsights {
        var words: [SentenceWordInsight] = []
        words.reserveCapacity(8)
        var seen: Set<String> = []

        for token in tokenizer.tokenize(sentence) where token.isWord {
            let normalized = normalizer.normalize(token.text)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)

            let meaning = dictionaryManager.lookup(token.text)
            let pronunciation = transliterator.pronounce(token.text)
            let id = "\(normalized)#\(words.count)"
            words.append(
                SentenceWordInsight(
                    id: id,
                    word: token.text,
                    normalizedKey: normalized,
                    meaning: meaning,
                    pronunciation: pronunciation
                )
            )
        }

        return SentenceInsights(sentence: sentence, words: words)
    }
}
