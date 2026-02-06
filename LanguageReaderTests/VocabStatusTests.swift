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

    func testStatusCycle() {
        XCTAssertEqual(VocabStatus.new.next, .learning)
        XCTAssertEqual(VocabStatus.learning.next, .known)
        XCTAssertEqual(VocabStatus.known.next, .new)
    }

    func testStatusCycleCompleteness() {
        let start = VocabStatus.new
        let afterOne = start.next
        let afterTwo = afterOne.next
        let afterThree = afterTwo.next
        XCTAssertEqual(afterThree, start)
    }

    func testAllCasesContainsAllStatuses() {
        XCTAssertEqual(VocabStatus.allCases.count, 3)
        XCTAssertTrue(VocabStatus.allCases.contains(.new))
        XCTAssertTrue(VocabStatus.allCases.contains(.learning))
        XCTAssertTrue(VocabStatus.allCases.contains(.known))
    }

    func testStatusRawValues() {
        XCTAssertEqual(VocabStatus.new.rawValue, "new")
        XCTAssertEqual(VocabStatus.learning.rawValue, "learning")
        XCTAssertEqual(VocabStatus.known.rawValue, "known")
    }

    func testDisplayAndColorMappingsAreUniquePerStatus() {
        let displayNames = Set(VocabStatus.allCases.map(\.displayName))
        let colorNames = Set(VocabStatus.allCases.map(\.colorName))

        XCTAssertEqual(displayNames.count, VocabStatus.allCases.count)
        XCTAssertEqual(colorNames.count, VocabStatus.allCases.count)
    }

    func testStatusCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in VocabStatus.allCases {
            let encoded = try encoder.encode(status)
            let decoded = try decoder.decode(VocabStatus.self, from: encoded)
            XCTAssertEqual(decoded, status)
        }
    }

    func testNormalizer() {
        let normalizer = TextNormalizer()
        XCTAssertEqual(normalizer.normalize("  HELLO "), "hello")
        XCTAssertEqual(normalizer.normalize("\n  ನಮಸ್ಕಾರ \t"), "ನಮಸ್ಕಾರ")
    }
}
