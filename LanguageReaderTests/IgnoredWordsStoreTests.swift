import XCTest
@testable import LanguageReader

final class IgnoredWordsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "IgnoredWordsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testAddContainsAndRemove() {
        let store = IgnoredWordsStore(defaults: defaults, storageKeyPrefix: "ignored_test")

        XCTAssertFalse(store.contains(normalizedKey: "word", languageCode: "de"))

        store.add(normalizedKey: "word", languageCode: "de")

        XCTAssertTrue(store.contains(normalizedKey: "word", languageCode: "de"))
        XCTAssertEqual(store.allKeys(languageCode: "de"), ["word"])

        store.remove(normalizedKey: "word", languageCode: "de")

        XCTAssertFalse(store.contains(normalizedKey: "word", languageCode: "de"))
        XCTAssertTrue(store.allKeys(languageCode: "de").isEmpty)
    }

    func testPersistsAcrossStoreInstances() {
        let storageKey = "ignored_shared"
        let writer = IgnoredWordsStore(defaults: defaults, storageKeyPrefix: storageKey)

        writer.add(normalizedKey: "alpha", languageCode: "kn")
        writer.add(normalizedKey: "beta", languageCode: "kn")

        let reader = IgnoredWordsStore(defaults: defaults, storageKeyPrefix: storageKey)
        XCTAssertTrue(reader.contains(normalizedKey: "alpha", languageCode: "kn"))
        XCTAssertTrue(reader.contains(normalizedKey: "beta", languageCode: "kn"))
        XCTAssertEqual(reader.allKeys(languageCode: "kn"), ["alpha", "beta"])
    }

    func testMigratesLegacyEntriesIntoKannadaScope() {
        defaults.set(["old"], forKey: "ignored_normalized_words_v1")
        let store = IgnoredWordsStore(defaults: defaults, storageKeyPrefix: "ignored_migrated")

        store.migrateLegacyEntriesIfNeeded(to: .kannada)

        XCTAssertFalse(store.hasLegacyEntries)
        XCTAssertEqual(store.allKeys(languageCode: "kn"), ["old"])
        XCTAssertTrue((defaults.array(forKey: "ignored_normalized_words_v1") as? [String] ?? []).isEmpty)
    }
}
