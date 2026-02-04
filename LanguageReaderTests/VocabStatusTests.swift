import XCTest
@testable import LanguageReader

final class VocabStatusTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(VocabStatus.new.displayName, "New")
        XCTAssertEqual(VocabStatus.learning.displayName, "Learning")
        XCTAssertEqual(VocabStatus.known.displayName, "Known")
    }

    func testColorNames() {
        XCTAssertEqual(VocabStatus.new.colorName, "blue")
        XCTAssertEqual(VocabStatus.learning.colorName, "yellow")
        XCTAssertEqual(VocabStatus.known.colorName, "gray")
    }

    func testNormalizer() {
        let normalizer = TextNormalizer()
        XCTAssertEqual(normalizer.normalize("  HELLO "), "hello")
        XCTAssertEqual(normalizer.normalize("\n  ನಮಸ್ಕಾರ \t"), "ನಮಸ್ಕಾರ")
    }
}
