import XCTest
import SQLite3
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

    func testSQLiteProviderLookupReturnsExpectedMeaning() throws {
        let url = try makeSQLiteDictionary(entries: [
            "hello": "hi",
            "ನಮಸ್ಕಾರ": "hello"
        ])
        let provider = try XCTUnwrap(
            SQLiteDictionaryProvider(fileURL: url, sourceDescription: "test dictionary")
        )

        XCTAssertEqual(provider.lookup(normalizedKey: "hello"), "hi")
        XCTAssertEqual(provider.lookup(normalizedKey: "ನಮಸ್ಕಾರ"), "hello")
        XCTAssertNil(provider.lookup(normalizedKey: "missing"))
    }

    func testSQLiteProviderSupportsConcurrentReads() throws {
        let url = try makeSQLiteDictionary(entries: [
            "hello": "hi",
            "world": "earth",
            "ನಮಸ್ಕಾರ": "hello"
        ])
        let provider = try XCTUnwrap(
            SQLiteDictionaryProvider(fileURL: url, sourceDescription: "test dictionary")
        )
        let lookups: [(word: String, expected: String?)] = [
            ("hello", "hi"),
            ("world", "earth"),
            ("ನಮಸ್ಕಾರ", "hello"),
            ("missing", nil)
        ]

        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()
        let lock = NSLock()
        var failures: [String] = []

        for i in 0..<300 {
            let lookup = lookups[i % lookups.count]
            group.enter()
            queue.async {
                let result = provider.lookup(normalizedKey: lookup.word)
                if result != lookup.expected {
                    lock.lock()
                    failures.append("word=\(lookup.word) expected=\(lookup.expected ?? "nil") got=\(result ?? "nil")")
                    lock.unlock()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertTrue(failures.isEmpty, failures.prefix(8).joined(separator: "\n"))
    }

    private func makeSQLiteDictionary(entries: [String: String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictionary-test-\(UUID().uuidString).sqlite")

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            throw NSError(domain: "DictionaryTests", code: 1)
        }
        defer { sqlite3_close(db) }

        let createStatement = "CREATE TABLE entries (key TEXT PRIMARY KEY, meaning TEXT NOT NULL);"
        guard sqlite3_exec(db, createStatement, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "DictionaryTests", code: 2)
        }

        var insertStatement: OpaquePointer?
        let insertSQL = "INSERT INTO entries (key, meaning) VALUES (?, ?);"
        guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK,
              let insertStatement else {
            throw NSError(domain: "DictionaryTests", code: 3)
        }
        defer { sqlite3_finalize(insertStatement) }

        let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (key, meaning) in entries {
            sqlite3_reset(insertStatement)
            sqlite3_clear_bindings(insertStatement)
            key.withCString { cString in
                sqlite3_bind_text(insertStatement, 1, cString, -1, sqliteTransient)
            }
            meaning.withCString { cString in
                sqlite3_bind_text(insertStatement, 2, cString, -1, sqliteTransient)
            }
            guard sqlite3_step(insertStatement) == SQLITE_DONE else {
                throw NSError(domain: "DictionaryTests", code: 4)
            }
        }

        return url
    }
}
