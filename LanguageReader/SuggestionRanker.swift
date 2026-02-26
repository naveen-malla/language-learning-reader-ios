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
            (suggestion, score(suggestion: suggestion, baseIndex: index, context: context))
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }
            .map(\.0)
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

        return value
    }
}
