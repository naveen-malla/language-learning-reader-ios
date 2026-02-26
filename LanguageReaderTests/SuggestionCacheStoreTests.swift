import Foundation
import XCTest
@testable import LanguageReader

final class SuggestionCacheStoreTests: XCTestCase {
    func testCachedSuggestionsExpireByTTL() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = SuggestionCacheStore(
            defaults: defaults,
            storageKey: "cache",
            now: { now }
        )

        let suggestion = makeSuggestion(videoID: "KaBYEZ6q2tY")
        await store.saveSuggestions([suggestion])

        let fresh = await store.cachedSuggestions()
        XCTAssertEqual(fresh.map(\.videoID), [suggestion.videoID])

        now = now.addingTimeInterval(9 * 60 * 60)
        let expired = await store.cachedSuggestions()
        XCTAssertTrue(expired.isEmpty)

        let fallback = await store.cachedSuggestions(includeExpired: true)
        XCTAssertEqual(fallback.map(\.videoID), [suggestion.videoID])
    }

    func testValidationFailureExpires() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = SuggestionCacheStore(
            defaults: defaults,
            storageKey: "cache",
            now: { now }
        )

        await store.storeValidationFailure(videoID: "KaBYEZ6q2tY")

        let cached = await store.cachedValidation(for: "KaBYEZ6q2tY")
        XCTAssertNotNil(cached as Any?)
        if case .some(nil) = cached {
            // expected
        } else {
            XCTFail("Expected cached validation marker for known invalid video")
        }

        now = now.addingTimeInterval(13 * 60 * 60)
        let expired = await store.cachedValidation(for: "KaBYEZ6q2tY")
        XCTAssertNil(expired as Any?)
    }

    func testTrustedChannelsAreDeduplicated() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        let store = SuggestionCacheStore(defaults: defaults, storageKey: "cache")

        await store.addTrustedChannel(channelID: "UC123", channelTitle: "One")
        await store.addTrustedChannel(channelID: "UC123", channelTitle: "One Updated")
        await store.addTrustedChannel(channelID: "UC456", channelTitle: "Two")

        let ids = await store.trustedChannelIDs().sorted()
        XCTAssertEqual(ids, ["UC123", "UC456"])
    }

    func testDiscoveryBackoffWindowProgressionAndExpiry() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = SuggestionCacheStore(
            defaults: defaults,
            storageKey: "cache",
            now: { now }
        )

        let initiallyBackingOff = await store.shouldBackoff()
        XCTAssertFalse(initiallyBackingOff)

        await store.recordDiscoveryFailure()
        let backingOffAfterFirstFailure = await store.shouldBackoff()
        XCTAssertTrue(backingOffAfterFirstFailure)

        let firstRetry = await store.nextRetryDate()
        XCTAssertNotNil(firstRetry)

        await store.recordDiscoveryFailure()
        let secondRetry = await store.nextRetryDate()
        XCTAssertNotNil(secondRetry)
        XCTAssertTrue(secondRetry! > firstRetry!)

        now = secondRetry!.addingTimeInterval(1)
        let backingOffAfterExpiry = await store.shouldBackoff()
        XCTAssertFalse(backingOffAfterExpiry)

        await store.recordDiscoverySuccess()
        let backingOffAfterSuccess = await store.shouldBackoff()
        XCTAssertFalse(backingOffAfterSuccess)
        let retryAfterSuccess = await store.nextRetryDate()
        XCTAssertNil(retryAfterSuccess)
    }

    private func makeSuggestion(videoID: String) -> YouTubeSuggestedVideo {
        YouTubeSuggestedVideo(
            videoID: videoID,
            title: "Title \(videoID)",
            channelTitle: "Channel \(videoID)",
            channelID: "channel-\(videoID)",
            category: "Basics",
            durationSeconds: 120,
            thumbnailURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
