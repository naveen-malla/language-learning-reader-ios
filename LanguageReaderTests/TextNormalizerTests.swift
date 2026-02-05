import XCTest
@testable import LanguageReader

final class TextNormalizerTests: XCTestCase {
    private var normalizer: TextNormalizer!

    override func setUp() {
        super.setUp()
        normalizer = TextNormalizer()
    }

    func testNormalizesBasicText() {
        XCTAssertEqual(normalizer.normalize("Hello"), "hello")
        XCTAssertEqual(normalizer.normalize("WORLD"), "world")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(normalizer.normalize("  hello  "), "hello")
        XCTAssertEqual(normalizer.normalize("\n\thello\t\n"), "hello")
    }

    func testHandlesEmptyString() {
        XCTAssertEqual(normalizer.normalize(""), "")
        XCTAssertEqual(normalizer.normalize("   "), "")
    }

    func testHandlesKannadaText() {
        XCTAssertEqual(normalizer.normalize("  ನಮಸ್ಕಾರ "), "ನಮಸ್ಕಾರ")
        XCTAssertEqual(normalizer.normalize("ಕನ್ನಡ"), "ಕನ್ನಡ")
    }

    func testHandlesMixedCase() {
        XCTAssertEqual(normalizer.normalize("HeLLo WoRLd"), "hello world")
    }

    func testPreservesNonAsciiCharacters() {
        XCTAssertEqual(normalizer.normalize("Café"), "café")
        XCTAssertEqual(normalizer.normalize("日本語"), "日本語")
    }
}
