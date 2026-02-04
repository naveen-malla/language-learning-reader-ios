import XCTest
@testable import LanguageReader

final class DictionaryTests: XCTestCase {
    func testSampleProviderLookup() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        XCTAssertEqual(provider.lookup(normalizedKey: "hello"), "hi")
        XCTAssertNil(provider.lookup(normalizedKey: "missing"))
    }

    func testManagerUsesNormalizer() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = DictionaryManager(provider: provider)
        XCTAssertEqual(manager.lookup("  HELLO "), "hi")
    }
}
