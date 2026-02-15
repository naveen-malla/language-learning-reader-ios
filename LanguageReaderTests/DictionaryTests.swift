import XCTest
@testable import LanguageReader

final class DictionaryTests: XCTestCase {
    func testSampleProviderLookup() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi", "ನಮಸ್ಕಾರ": "hello"])
        XCTAssertEqual(provider.lookup(normalizedKey: "hello"), "hi")
        XCTAssertEqual(provider.lookup(normalizedKey: "ನಮಸ್ಕಾರ"), "hello")
        XCTAssertNil(provider.lookup(normalizedKey: "missing"))
    }

    func testManagerUsesNormalizerAndDetailedLookup() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = DictionaryManager(
            provider: provider,
            overrideStore: DictionaryOverrideStore(fileURL: nil, missingURL: nil)
        )
        let result = manager.lookupDetailed("  HELLO ")
        XCTAssertEqual(result.normalizedKey, "hello")
        XCTAssertEqual(result.meaning, "hi")
        XCTAssertEqual(result.path, .direct)
    }

    func testLookupResultPathDisplayNamesAreStable() {
        XCTAssertEqual(DictionaryLookupResult.Path.override.displayName, "Override")
        XCTAssertEqual(DictionaryLookupResult.Path.direct.displayName, "Direct")
        XCTAssertEqual(DictionaryLookupResult.Path.suffix.displayName, "Suffix")
        XCTAssertEqual(DictionaryLookupResult.Path.redirect.displayName, "Redirect")
        XCTAssertEqual(DictionaryLookupResult.Path.cache.displayName, "Cache")
        XCTAssertEqual(DictionaryLookupResult.Path.remote.displayName, "Remote")
        XCTAssertEqual(DictionaryLookupResult.Path.none.displayName, "None")
    }

    func testQualityEvaluationComputesCoverageAndAccuracy() {
        let provider = SampleDictionaryProvider(entries: [
            "hello": "greeting",
            "world": "earth"
        ])
        let manager = DictionaryManager(
            provider: provider,
            overrideStore: DictionaryOverrideStore(fileURL: nil, missingURL: nil),
            cloudStore: DictionaryCloudMeaningStore(fileURL: nil, entries: []),
            remoteProvider: nil,
            sourceLanguageProvider: { "en" },
            targetLanguageProvider: { "en" }
        )

        let fixture = DictionaryQualityFixture(
            name: "Test Fixture",
            languageCode: "en",
            corpusSentences: ["hello world unknown hello"],
            goldEntries: [
                .init(word: "hello", acceptedMeanings: ["greeting"]),
                .init(word: "world", acceptedMeanings: ["earth"]),
                .init(word: "unknown", acceptedMeanings: ["missing"])
            ],
            thresholds: DictionaryQualityThresholds(
                tokenCoverageMinimum: 0.70,
                uniqueCoverageMinimum: 0.60,
                goldHitRateMinimum: 0.60,
                goldAccuracyMinimum: 0.60
            )
        )

        let snapshot = manager.evaluateQuality(fixture: fixture)

        XCTAssertEqual(snapshot.tokenTotal, 4)
        XCTAssertEqual(snapshot.tokenHits, 3)
        XCTAssertEqual(snapshot.uniqueTotal, 3)
        XCTAssertEqual(snapshot.uniqueHits, 2)
        XCTAssertEqual(snapshot.goldTotal, 3)
        XCTAssertEqual(snapshot.goldHits, 2)
        XCTAssertEqual(snapshot.goldCorrect, 2)
        XCTAssertEqual(snapshot.tokenCoverage, 0.75, accuracy: 0.001)
        XCTAssertEqual(snapshot.uniqueCoverage, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.goldHitRate, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.goldAccuracy, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.requestedLanguageCode, "en")
        XCTAssertEqual(snapshot.fixtureLanguageCode, "en")
        XCTAssertFalse(snapshot.usedFallbackFixture)
        XCTAssertTrue(snapshot.thresholdPassed)
    }

    func testQualityEvaluationThresholdGateFailsWhenAccuracyIsLow() {
        let provider = SampleDictionaryProvider(entries: [
            "hello": "salutation",
            "world": "earth"
        ])
        let manager = DictionaryManager(
            provider: provider,
            overrideStore: DictionaryOverrideStore(fileURL: nil, missingURL: nil),
            cloudStore: DictionaryCloudMeaningStore(fileURL: nil, entries: []),
            remoteProvider: nil,
            sourceLanguageProvider: { "en" },
            targetLanguageProvider: { "en" }
        )

        let fixture = DictionaryQualityFixture(
            name: "Strict Accuracy",
            languageCode: "en",
            corpusSentences: ["hello world"],
            goldEntries: [
                .init(word: "hello", acceptedMeanings: ["hello"], matchMode: .exact),
                .init(word: "world", acceptedMeanings: ["earth"], matchMode: .exact)
            ],
            thresholds: DictionaryQualityThresholds(
                tokenCoverageMinimum: 0.90,
                uniqueCoverageMinimum: 0.90,
                goldHitRateMinimum: 1.0,
                goldAccuracyMinimum: 1.0
            )
        )

        let snapshot = manager.evaluateQuality(fixture: fixture)

        XCTAssertEqual(snapshot.goldAccuracy, 0.5, accuracy: 0.001)
        XCTAssertFalse(snapshot.thresholdPassed)
        XCTAssertTrue(snapshot.thresholdChecks.contains { check in
            check.metricName == "Gold Accuracy" && !check.passed
        })
    }

    func testQualityEvaluationUsesFallbackFixtureForUnsupportedLanguage() {
        let provider = SampleDictionaryProvider(entries: [
            "hello": "greeting",
            "house": "home",
            "book": "book",
            "school": "school",
            "food": "food",
            "water": "water",
            "story": "story",
            "language": "language",
            "window": "window",
            "letter": "letter",
            "market": "market"
        ])
        let manager = DictionaryManager(
            provider: provider,
            overrideStore: DictionaryOverrideStore(fileURL: nil, missingURL: nil),
            cloudStore: DictionaryCloudMeaningStore(fileURL: nil, entries: []),
            remoteProvider: nil,
            sourceLanguageProvider: { "es-MX" },
            targetLanguageProvider: { "en" }
        )

        let snapshot = manager.evaluateQuality()

        XCTAssertEqual(snapshot.requestedLanguageCode, "es-mx")
        XCTAssertEqual(snapshot.fixtureLanguageCode, "en")
        XCTAssertEqual(snapshot.fixtureName, "English Core V1")
        XCTAssertTrue(snapshot.usedFallbackFixture)
    }
}
