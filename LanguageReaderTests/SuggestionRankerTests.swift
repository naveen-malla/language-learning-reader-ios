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
        XCTAssertEqual(ranked[1].videoID, "2")
    }

    private func makeSuggestion(
        videoID: String,
        title: String,
        channel: String,
        category: String,
        duration: Int
    ) -> YouTubeSuggestedVideo {
        YouTubeSuggestedVideo(
            videoID: videoID,
            title: title,
            channelTitle: channel,
            category: category,
            durationSeconds: duration,
            thumbnailURL: nil
        )
    }
}
