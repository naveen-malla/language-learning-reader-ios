import XCTest
@testable import LanguageReader

/// Tests for DictionaryManager with edge cases.
final class DictionaryManagerTests: XCTestCase {
    
    func testLookupWithWhitespace() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = DictionaryManager(provider: provider)
        
        // Should normalize whitespace
        XCTAssertEqual(manager.lookup("  hello  "), "hi")
        XCTAssertEqual(manager.lookup("\nhello\t"), "hi")
    }
    
    func testLookupWithMixedCase() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = DictionaryManager(provider: provider)
        
        // Should normalize case
        XCTAssertEqual(manager.lookup("HELLO"), "hi")
        XCTAssertEqual(manager.lookup("HeLLo"), "hi")
    }
    
    func testLookupMissingWord() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = DictionaryManager(provider: provider)
        
        XCTAssertNil(manager.lookup("missing"))
        XCTAssertNil(manager.lookup(""))
    }
    
    func testLookupEmptyString() {
        let provider = SampleDictionaryProvider(entries: ["hello": "hi"])
        let manager = DictionaryManager(provider: provider)
        
        XCTAssertNil(manager.lookup(""))
        XCTAssertNil(manager.lookup("   "))
    }
    
    func testSourceDescription() {
        let provider = SampleDictionaryProvider()
        let manager = DictionaryManager(provider: provider)
        
        XCTAssertEqual(manager.sourceDescription, "Bundled sample dictionary")
    }
    
    func testLookupKannadaWords() {
        let provider = SampleDictionaryProvider()
        let manager = DictionaryManager(provider: provider)
        
        // Test with actual sample data
        XCTAssertEqual(manager.lookup("ನಮಸ್ಕಾರ"), "hello")
        XCTAssertEqual(manager.lookup("  ನಮಸ್ಕಾರ  "), "hello")
    }
}
