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
        XCTAssertEqual(DictionaryLookupResult.Path.none.displayName, "None")
    }
}
