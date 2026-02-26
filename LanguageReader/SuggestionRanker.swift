import Foundation

struct SuggestionRankingContext {
    let followedChannels: Set<String>
    let categoryHistory: [String: Int]
    let channelHistory: [String: Int]

    static let empty = SuggestionRankingContext(
        followedChannels: [],
        categoryHistory: [:],
        channelHistory: [:]
    )
}

enum SuggestionRanker {
    static func normalizeChannel(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizeCategory(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func rank(
        _ suggestions: [YouTubeSuggestedVideo],
        context: SuggestionRankingContext
    ) -> [YouTubeSuggestedVideo] {
        let scored = suggestions.enumerated().map { index, suggestion in
            ScoredSuggestion(
                suggestion: suggestion,
                baseScore: score(suggestion: suggestion, baseIndex: index, context: context)
            )
        }

        var remaining = scored
        var pickedCategoryCounts: [String: Int] = [:]
        var ordered: [YouTubeSuggestedVideo] = []

        while !remaining.isEmpty {
            let bestIndex = remaining.indices.max { lhs, rhs in
                let lhsScore = diversityAdjustedScore(
                    for: remaining[lhs],
                    pickedCategoryCounts: pickedCategoryCounts
                )
                let rhsScore = diversityAdjustedScore(
                    for: remaining[rhs],
                    pickedCategoryCounts: pickedCategoryCounts
                )
                if lhsScore != rhsScore {
                    return lhsScore < rhsScore
                }
                return remaining[lhs].suggestion.title.localizedCaseInsensitiveCompare(
                    remaining[rhs].suggestion.title
                ) == .orderedDescending
            }!

            let chosen = remaining.remove(at: bestIndex).suggestion
            ordered.append(chosen)
            let categoryKey = normalizeCategory(chosen.category)
            pickedCategoryCounts[categoryKey, default: 0] += 1
        }

        return ordered
    }

    private static func score(
        suggestion: YouTubeSuggestedVideo,
        baseIndex: Int,
        context: SuggestionRankingContext
    ) -> Int {
        var value = max(0, 300 - (baseIndex * 10))

        let channelKey = normalizeChannel(suggestion.channelTitle)
        let categoryKey = normalizeCategory(suggestion.category)

        if context.followedChannels.contains(channelKey) {
            value += 600
        }

        value += (context.categoryHistory[categoryKey] ?? 0) * 40
        value += (context.channelHistory[channelKey] ?? 0) * 25

        if suggestion.durationSeconds > 0 {
            let durationBias = max(0, (YouTubeImportService.maxBeginnerDurationSeconds - suggestion.durationSeconds) / 60)
            value += durationBias
        }

        if let publishedAt = suggestion.publishedAt {
            let days = max(0, Int(Date().timeIntervalSince(publishedAt) / (24 * 3600)))
            let recencyBonus = max(0, 40 - min(days, 40))
            value += recencyBonus
        }

        return value
    }

    private static func diversityAdjustedScore(
        for suggestion: ScoredSuggestion,
        pickedCategoryCounts: [String: Int]
    ) -> Int {
        let categoryKey = normalizeCategory(suggestion.suggestion.category)
        let count = pickedCategoryCounts[categoryKey, default: 0]
        return suggestion.baseScore - (count * 120)
    }

    private struct ScoredSuggestion {
        let suggestion: YouTubeSuggestedVideo
        let baseScore: Int
    }
}
