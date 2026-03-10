import XCTest
@testable import LanguageReader

final class SuggestionRankerTests: XCTestCase {
    func testFollowedChannelGetsPriority() {
        let followed = "  Fav Channel  "
        let suggestions = [
            makeSuggestion(videoID: "1", title: "General", channel: "Other Channel", category: "Basics", duration: 240),
            makeSuggestion(videoID: "2", title: "Followed", channel: "Fav Channel", category: "Grammar", duration: 240)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [followed],
                categoryHistory: [:],
                channelHistory: [:]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testCategoryAndChannelHistoryBoostsOrdering() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "A", channel: "Alpha", category: "Stories", duration: 300),
            makeSuggestion(videoID: "2", title: "B", channel: "Beta", category: "Grammar", duration: 300),
            makeSuggestion(videoID: "3", title: "C", channel: "Gamma", category: "Grammar", duration: 300)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [],
                categoryHistory: ["grammar": 3],
                channelHistory: ["gamma": 2]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "3")
        XCTAssertEqual(ranked[1].videoID, "1")
    }

    func testRecencyBoostPrefersFreshSuggestion() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let freshDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let suggestions = [
            makeSuggestion(
                videoID: "1",
                title: "Old",
                channel: "Alpha",
                category: "Basics",
                duration: 240,
                publishedAt: oldDate
            ),
            makeSuggestion(
                videoID: "2",
                title: "Fresh",
                channel: "Beta",
                category: "Basics",
                duration: 240,
                publishedAt: freshDate
            )
        ]

        let ranked = SuggestionRanker.rank(suggestions, context: .empty)
        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testDurationBiasRewardsShorterVideosWithinDurationWindow() {
        let preferred = YouTubeImportService.preferredDurationSeconds
        let suggestions = [
            makeSuggestion(
                videoID: "1",
                title: "Short",
                channel: "Alpha",
                category: "Basics",
                duration: 300
            ),
            makeSuggestion(
                videoID: "2",
                title: "Preferred",
                channel: "Beta",
                category: "Basics",
                duration: preferred
            ),
            makeSuggestion(
                videoID: "3",
                title: "Long",
                channel: "Gamma",
                category: "Basics",
                duration: 1200
            )
        ]

        let ranked = SuggestionRanker.rank(suggestions, context: .empty)
        XCTAssertEqual(ranked.first?.videoID, "1")
    }

    func testDiversityPenaltyPrefersDifferentCategoryForSecondPick() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Top Grammar", channel: "Fav A", category: "Grammar", duration: 360),
            makeSuggestion(videoID: "2", title: "Second Grammar", channel: "Fav B", category: "Grammar", duration: 360),
            makeSuggestion(videoID: "3", title: "Story Option", channel: "Story Channel", category: "Stories", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: ["fav a", "fav b"],
                categoryHistory: ["stories": 15],
                channelHistory: [:]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "1")
        XCTAssertEqual(ranked[1].videoID, "3")
    }

    func testTieBreakUsesAlphabeticalTitleWhenScoresAreEqual() {
        let older = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let fresh = Date()
        let suggestions = [
            makeSuggestion(
                videoID: "1",
                title: "Beta",
                channel: "Alpha Channel",
                category: "Basics",
                duration: 360,
                publishedAt: older
            ),
            makeSuggestion(
                videoID: "2",
                title: "Alpha",
                channel: "Beta Channel",
                category: "Basics",
                duration: 360,
                publishedAt: fresh
            )
        ]

        let ranked = SuggestionRanker.rank(suggestions, context: .empty)
        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testHistoryMatchingIgnoresCaseAndWhitespace() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Target", channel: "  Kannada Focus  ", category: "  Grammar  ", duration: 360),
            makeSuggestion(videoID: "2", title: "Other", channel: "Other", category: "Basics", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [],
                categoryHistory: ["  Grammar ": 1, "gRaMmAr": 1],
                channelHistory: [" Kannada Focus ": 1, "kannada focus": 1]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "1")
    }

    func testRankReturnsEmptyForEmptySuggestions() {
        let ranked = SuggestionRanker.rank([], context: .empty)
        XCTAssertTrue(ranked.isEmpty)
    }

    func testWhitespaceOnlyContextKeysDoNotAffectRanking() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Normal", channel: "Alpha", category: "Basics", duration: 360),
            makeSuggestion(videoID: "2", title: "Blank", channel: "   ", category: " \n ", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: ["   ", "\n"],
                categoryHistory: ["  ": 10, "\n": 5],
                channelHistory: ["  ": 20]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "1")
    }

    func testDuplicateNormalizedHistoryKeysAreSummed() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Base Index Leader", channel: "Other", category: "Other", duration: 360),
            makeSuggestion(videoID: "2", title: "Normalized Target", channel: "  Kannada Focus ", category: "  Grammar ", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [],
                categoryHistory: [" grammar ": 2, "GRAMMAR": 3],
                channelHistory: ["kannada focus": 1, " Kannada Focus ": 1]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testMixedBlankAndValidHistoryKeysIgnoreBlankAndSumValid() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Missing Metadata", channel: "", category: "", duration: 360),
            makeSuggestion(videoID: "2", title: "Normalized Target", channel: "  Kannada Focus ", category: "  Grammar ", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [],
                categoryHistory: [" grammar ": 2, "GRAMMAR": 1, "   ": 900, "\n": 400],
                channelHistory: ["kannada focus": 1, " Kannada Focus ": 2, "\t": 700]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testDiversityPenaltyNormalizesCategoryVariants() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Grammar Prime", channel: "Fav A", category: "Grammar", duration: 360),
            makeSuggestion(videoID: "2", title: "Grammar Variant", channel: "Fav B", category: "  grammar  ", duration: 360),
            makeSuggestion(videoID: "3", title: "Story Escape", channel: "Story Channel", category: "Stories", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: ["fav a", "fav b"],
                categoryHistory: ["stories": 14],
                channelHistory: ["fav a": 1]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "1")
        XCTAssertEqual(ranked[1].videoID, "3")
    }

    func testWhitespaceOnlyHistoryDoesNotBoostEmptyMetadata() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Missing Metadata", channel: "", category: "", duration: 360),
            makeSuggestion(videoID: "2", title: "Known", channel: "Known Channel", category: "Known", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [],
                categoryHistory: ["   ": 20, "\n\t": 10],
                channelHistory: ["   ": 20]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testWhitespaceOnlyFollowedChannelDoesNotMatchEmptyChannel() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Missing Channel", channel: "", category: "Basics", duration: 360),
            makeSuggestion(videoID: "2", title: "Known Channel", channel: "Kannada Focus", category: "Basics", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: ["   ", "\n"],
                categoryHistory: [:],
                channelHistory: [:]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testNonPositiveHistoryValuesAreIgnored() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Base Index Leader", channel: "Other", category: "Other", duration: 360),
            makeSuggestion(videoID: "2", title: "Target", channel: "Kannada Focus", category: "Grammar", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [],
                categoryHistory: ["grammar": -500, "other": 0, "GRAMMAR": 2],
                channelHistory: ["kannada focus": -10, " Kannada Focus ": 2, "other": 0]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testNonPositiveNormalizedVariantsDoNotCancelPositiveHistory() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Base Index Leader", channel: "Other", category: "Other", duration: 360),
            makeSuggestion(videoID: "2", title: "Target", channel: "Kannada Focus", category: "Grammar", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: [],
                categoryHistory: [" grammar ": 3, "GRAMMAR": -500, "other": 0],
                channelHistory: [" Kannada Focus ": 2, "kannada focus": 0, "other": -10]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "2")
    }

    func testDiversityAdjustedTieBreakFallsBackToAlphabeticalTitle() {
        let suggestions = [
            makeSuggestion(videoID: "1", title: "Grammar Prime", channel: "Fav A", category: "Grammar", duration: 360),
            makeSuggestion(videoID: "2", title: "Zulu Grammar", channel: "Fav B", category: "Grammar", duration: 360),
            makeSuggestion(videoID: "3", title: "Alpha Stories", channel: "Story Channel", category: "Stories", duration: 360)
        ]

        let ranked = SuggestionRanker.rank(
            suggestions,
            context: SuggestionRankingContext(
                followedChannels: ["fav a", "fav b"],
                categoryHistory: ["stories": 17],
                channelHistory: [:]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "1")
        XCTAssertEqual(ranked[1].videoID, "3")
        XCTAssertEqual(ranked[2].videoID, "2")
    }

    private func makeSuggestion(
        videoID: String,
        title: String,
        channel: String,
        category: String,
        duration: Int,
        publishedAt: Date? = nil
    ) -> YouTubeSuggestedVideo {
        YouTubeSuggestedVideo(
            videoID: videoID,
            title: title,
            channelTitle: channel,
            channelID: nil,
            category: category,
            durationSeconds: duration,
            thumbnailURL: nil,
            publishedAt: publishedAt
        )
    }
}
