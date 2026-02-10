import Foundation

enum WordLearningVisualState: Equatable {
    case ignored
    case known
    case learning(level: VocabStatus)
    case new

    var accessibilityLabel: String {
        switch self {
        case .ignored:
            return "ignored"
        case .known:
            return "known"
        case .learning(let level):
            return level.displayName.lowercased()
        case .new:
            return "new"
        }
    }

    var levelBadge: String? {
        switch self {
        case .learning(let level):
            return level.shortLabel
        case .ignored, .known, .new:
            return nil
        }
    }

    var isVisibleInSentenceList: Bool {
        switch self {
        case .learning, .new:
            return true
        case .ignored, .known:
            return false
        }
    }
}

struct WordLearningStateResolver {
    private let normalizer: TextNormalizer

    init(normalizer: TextNormalizer = TextNormalizer()) {
        self.normalizer = normalizer
    }

    func state(
        for word: String,
        statusByKey: [String: VocabStatus],
        ignoredKeys: Set<String>
    ) -> WordLearningVisualState {
        let normalized = normalizer.normalize(word)
        return state(forNormalizedKey: normalized, statusByKey: statusByKey, ignoredKeys: ignoredKeys)
    }

    func state(
        forNormalizedKey normalizedKey: String,
        statusByKey: [String: VocabStatus],
        ignoredKeys: Set<String>
    ) -> WordLearningVisualState {
        guard !normalizedKey.isEmpty else { return .new }

        if ignoredKeys.contains(normalizedKey) {
            return .ignored
        }

        guard let status = statusByKey[normalizedKey] else {
            return .new
        }

        if status.isKnown {
            return .known
        }

        return .learning(level: status)
    }
}
