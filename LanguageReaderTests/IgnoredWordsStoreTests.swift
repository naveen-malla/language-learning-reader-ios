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
        let store = IgnoredWordsStore(defaults: defaults, storageKey: "ignored_test")

        XCTAssertFalse(store.contains(normalizedKey: "word"))

        store.add(normalizedKey: "word")

        XCTAssertTrue(store.contains(normalizedKey: "word"))
        XCTAssertEqual(store.allKeys(), ["word"])

        store.remove(normalizedKey: "word")

        XCTAssertFalse(store.contains(normalizedKey: "word"))
        XCTAssertTrue(store.allKeys().isEmpty)
    }

    func testPersistsAcrossStoreInstances() {
        let storageKey = "ignored_shared"
        let writer = IgnoredWordsStore(defaults: defaults, storageKey: storageKey)

        writer.add(normalizedKey: "alpha")
        writer.add(normalizedKey: "beta")

        let reader = IgnoredWordsStore(defaults: defaults, storageKey: storageKey)
        XCTAssertTrue(reader.contains(normalizedKey: "alpha"))
        XCTAssertTrue(reader.contains(normalizedKey: "beta"))
        XCTAssertEqual(reader.allKeys(), ["alpha", "beta"])
    }
}
