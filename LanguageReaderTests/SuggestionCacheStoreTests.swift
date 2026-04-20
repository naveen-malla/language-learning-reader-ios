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

    func testValidationSuccessExpires() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = SuggestionCacheStore(
            defaults: defaults,
            storageKey: "cache",
            now: { now }
        )

        let suggestion = makeSuggestion(videoID: "KaBYEZ6q2tY")
        await store.storeValidationSuccess(suggestion)

        let cached = await store.cachedValidation(for: suggestion.videoID)
        if case .some(.some(let resolved)) = cached {
            XCTAssertEqual(resolved.videoID, suggestion.videoID)
        } else {
            XCTFail("Expected cached valid suggestion")
        }

        now = now.addingTimeInterval(25 * 60 * 60)
        let expired = await store.cachedValidation(for: suggestion.videoID)
        XCTAssertNil(expired as Any?)
    }

    func testSaveSuggestionsPrunesStaleValidationRecords() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = SuggestionCacheStore(
            defaults: defaults,
            storageKey: "cache",
            now: { now }
        )

        await store.storeValidationFailure(videoID: "OLD_FAIL")
        await store.storeValidationSuccess(makeSuggestion(videoID: "OLD_SUCCESS"))

        now = now.addingTimeInterval(26 * 60 * 60)
        await store.saveSuggestions([makeSuggestion(videoID: "FRESH")])

        let staleFailure = await store.cachedValidation(for: "OLD_FAIL")
        let staleSuccess = await store.cachedValidation(for: "OLD_SUCCESS")
        XCTAssertNil(staleFailure as Any?)
        XCTAssertNil(staleSuccess as Any?)
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

    func testDiscoveryBackoffCapsAtEightyMinutesAndResetsAfterSuccess() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = SuggestionCacheStore(
            defaults: defaults,
            storageKey: "cache",
            now: { now }
        )

        for _ in 0..<6 {
            await store.recordDiscoveryFailure()
        }

        let cappedRetry = await store.nextRetryDate()
        guard let cappedRetry else {
            return XCTFail("Expected capped retry date")
        }
        XCTAssertEqual(cappedRetry.timeIntervalSince(now), TimeInterval(80 * 60), accuracy: 0.001)

        await store.recordDiscoverySuccess()
        await store.recordDiscoveryFailure()
        let retryAfterReset = await store.nextRetryDate()
        guard let retryAfterReset else {
            return XCTFail("Expected retry date after reset")
        }
        XCTAssertEqual(retryAfterReset.timeIntervalSince(now), TimeInterval(10 * 60), accuracy: 0.001)
    }

    func testCachesAreSeparatedByLanguage() async {
        let defaults = UserDefaults(suiteName: "SuggestionCacheStoreTests.\(UUID().uuidString)")!
        let store = SuggestionCacheStore(defaults: defaults, storageKey: "cache")

        await store.saveSuggestions([makeSuggestion(videoID: "GERMAN00001")], language: .german)
        await store.saveSuggestions([makeSuggestion(videoID: "KANNADA001")], language: .kannada)

        let german = await store.cachedSuggestions(language: .german)
        let kannada = await store.cachedSuggestions(language: .kannada)

        XCTAssertEqual(german.map(\.videoID), ["GERMAN00001"])
        XCTAssertEqual(kannada.map(\.videoID), ["KANNADA001"])
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
