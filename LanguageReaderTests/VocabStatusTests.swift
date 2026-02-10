import XCTest
@testable import LanguageReader

final class VocabStatusTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(VocabStatus.level1.displayName, "Level 1")
        XCTAssertEqual(VocabStatus.level2.displayName, "Level 2")
        XCTAssertEqual(VocabStatus.level3.displayName, "Level 3")
        XCTAssertEqual(VocabStatus.level4.displayName, "Level 4")
        XCTAssertEqual(VocabStatus.known.displayName, "Known")
    }

    func testShortLabels() {
        XCTAssertEqual(VocabStatus.level1.shortLabel, "1")
        XCTAssertEqual(VocabStatus.level2.shortLabel, "2")
        XCTAssertEqual(VocabStatus.level3.shortLabel, "3")
        XCTAssertEqual(VocabStatus.level4.shortLabel, "4")
        XCTAssertEqual(VocabStatus.known.shortLabel, "Known")
    }

    func testColorNames() {
        XCTAssertEqual(VocabStatus.level1.colorName, "green")
        XCTAssertEqual(VocabStatus.level2.colorName, "green")
        XCTAssertEqual(VocabStatus.level3.colorName, "green")
        XCTAssertEqual(VocabStatus.level4.colorName, "green")
        XCTAssertEqual(VocabStatus.known.colorName, "gray")
    }

    func testStatusCycle() {
        XCTAssertEqual(VocabStatus.level1.next, .level2)
        XCTAssertEqual(VocabStatus.level2.next, .level3)
        XCTAssertEqual(VocabStatus.level3.next, .level4)
        XCTAssertEqual(VocabStatus.level4.next, .known)
        XCTAssertEqual(VocabStatus.known.next, .level1)
    }

    func testStatusCycleCompleteness() {
        let start = VocabStatus.level1
        let afterOne = start.next
        let afterTwo = afterOne.next
        let afterThree = afterTwo.next
        let afterFour = afterThree.next
        let afterFive = afterFour.next
        XCTAssertEqual(afterFive, start)
    }

    func testAllCasesContainsAllStatuses() {
        XCTAssertEqual(VocabStatus.allCases.count, 5)
        XCTAssertEqual(VocabStatus.progression.count, 5)
        XCTAssertEqual(VocabStatus.learningLevels, [.level1, .level2, .level3, .level4])
        XCTAssertTrue(VocabStatus.allCases.contains(.level1))
        XCTAssertTrue(VocabStatus.allCases.contains(.level2))
        XCTAssertTrue(VocabStatus.allCases.contains(.level3))
        XCTAssertTrue(VocabStatus.allCases.contains(.level4))
        XCTAssertTrue(VocabStatus.allCases.contains(.known))
    }

    func testStatusRawValues() {
        XCTAssertEqual(VocabStatus.level1.rawValue, "level1")
        XCTAssertEqual(VocabStatus.level2.rawValue, "level2")
        XCTAssertEqual(VocabStatus.level3.rawValue, "level3")
        XCTAssertEqual(VocabStatus.level4.rawValue, "level4")
        XCTAssertEqual(VocabStatus.known.rawValue, "known")
    }

    func testDisplayAndColorMappingsAreUniqueEnoughForUI() {
        let displayNames = Set(VocabStatus.allCases.map(\.displayName))
        let shortLabels = Set(VocabStatus.allCases.map(\.shortLabel))

        XCTAssertEqual(displayNames.count, VocabStatus.allCases.count)
        XCTAssertEqual(shortLabels.count, VocabStatus.allCases.count)
    }

    func testStatusCodableRoundTripForCurrentValues() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in VocabStatus.allCases {
            let encoded = try encoder.encode(status)
            let decoded = try decoder.decode(VocabStatus.self, from: encoded)
            XCTAssertEqual(decoded, status)
        }
    }

    func testDecodesLegacyStoredValues() throws {
        let decoder = JSONDecoder()

        let legacyNew = try decoder.decode(VocabStatus.self, from: Data("\"new\"".utf8))
        let legacyLearning = try decoder.decode(VocabStatus.self, from: Data("\"learning\"".utf8))
        let legacyKnown = try decoder.decode(VocabStatus.self, from: Data("\"known\"".utf8))

        XCTAssertEqual(legacyNew, .level1)
        XCTAssertEqual(legacyLearning, .level2)
        XCTAssertEqual(legacyKnown, .known)
    }

    func testKnownAndLearningFlags() {
        XCTAssertTrue(VocabStatus.known.isKnown)
        XCTAssertFalse(VocabStatus.level1.isKnown)
        XCTAssertFalse(VocabStatus.known.isLearning)
        XCTAssertTrue(VocabStatus.level3.isLearning)
    }

    func testNormalizer() {
        let normalizer = TextNormalizer()
        XCTAssertEqual(normalizer.normalize("  HELLO "), "hello")
        XCTAssertEqual(normalizer.normalize("\n  ನಮಸ್ಕಾರ \t"), "ನಮಸ್ಕಾರ")
    }
}
