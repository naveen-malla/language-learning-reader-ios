import XCTest
@testable import LanguageReader

final class TransliteratorTests: XCTestCase {
    func testPronounceKannadaWord() {
        let result = Transliterator().pronounce("ಕನ್ನಡ")
        XCTAssertEqual(result, "kannada")
    }

    func testPronouncePreservesAscii() {
        let result = Transliterator().pronounce("hello")
        XCTAssertEqual(result, "hello")
    }
}
