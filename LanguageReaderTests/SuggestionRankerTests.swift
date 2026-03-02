import XCTest
@testable import LanguageReader

final class SuggestionRankerTests: XCTestCase {
    func testFollowedChannelGetsPriority() {
        let followed = "fav channel"
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
                categoryHistory: ["grammar": 2],
                channelHistory: ["kannada focus": 2]
            )
        )

        XCTAssertEqual(ranked.first?.videoID, "1")
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
