import XCTest
@testable import LanguageReader

final class DictionaryQualityTests: XCTestCase {
    func testGoldEntryMatchesContainsCaseInsensitive() {
        let entry = DictionaryQualityGoldEntry(
            word: "hello",
            acceptedMeanings: ["Greeting"]
        )

        XCTAssertTrue(entry.matches(actualMeaning: "A friendly greeting from a neighbor"))
    }

    func testGoldEntryExactMatchRequiresFullEquality() {
        let entry = DictionaryQualityGoldEntry(
            word: "house",
            acceptedMeanings: ["home"],
            matchMode: .exact
        )

        XCTAssertTrue(entry.matches(actualMeaning: "  Home  "))
        XCTAssertFalse(entry.matches(actualMeaning: "home sweet home"))
    }

    func testGoldEntryIgnoresEmptyMeanings() {
        let entry = DictionaryQualityGoldEntry(
            word: "tree",
            acceptedMeanings: ["", "tree"]
        )

        XCTAssertFalse(entry.matches(actualMeaning: "  "))
        XCTAssertTrue(entry.matches(actualMeaning: "Tree"))
    }

    func testQualityFixtureSelectsCanonicalLanguageCode() {
        let selection = DictionaryQualityFixture.select(for: " KN-IN ")

        XCTAssertEqual(selection.fixture.languageCode, "kn")
        XCTAssertFalse(selection.usedFallbackFixture)
    }
}
