import Foundation

struct SentenceReaderModel {
    let sentences: [SentenceBlock]

    init(blocks: [SentenceBlock]) {
        self.sentences = blocks.filter { !$0.isEmpty }
    }

    func clampedIndex(_ index: Int) -> Int {
        guard !sentences.isEmpty else { return 0 }
        return min(max(index, 0), sentences.count - 1)
    }

    func sentence(at index: Int) -> SentenceBlock? {
        guard !sentences.isEmpty else { return nil }
        let safeIndex = clampedIndex(index)
        return sentences[safeIndex]
    }

    func progress(for index: Int) -> Double {
        guard !sentences.isEmpty else { return 0 }
        guard sentences.count > 1 else { return 1 }
        let safeIndex = clampedIndex(index)
        return Double(safeIndex) / Double(sentences.count - 1)
    }

    func index(for progress: Double) -> Int {
        guard !sentences.isEmpty else { return 0 }
        let safeProgress = min(max(progress, 0), 1)
        let maxIndex = sentences.count - 1
        return Int(round(safeProgress * Double(maxIndex)))
    }
}

enum SentencePanelWordFilter {
    static func visibleWords(
        from words: [SentenceWordInsight],
        statusByKey: [String: VocabStatus],
        ignoredKeys: Set<String>
    ) -> [SentenceWordInsight] {
        words.filter { word in
            if ignoredKeys.contains(word.normalizedKey) {
                return false
            }
            return statusByKey[word.normalizedKey]?.isKnown != true
        }
    }
}
