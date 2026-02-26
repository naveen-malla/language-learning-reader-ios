import XCTest
@testable import LanguageReader

final class WordLearningStateResolverTests: XCTestCase {
    private let resolver = WordLearningStateResolver()

    func testStateForEmptyNormalizedKeyReturnsNew() {
        let state = resolver.state(forNormalizedKey: "", statusByKey: ["": .level2], ignoredKeys: [""])

        XCTAssertEqual(state, .new)
    }

    func testIgnoredOverridesStatus() {
        let state = resolver.state(
            forNormalizedKey: "ignored",
            statusByKey: ["ignored": .known],
            ignoredKeys: ["ignored"]
        )

        XCTAssertEqual(state, .ignored)
    }

    func testKnownStatusReturnsKnown() {
        let state = resolver.state(forNormalizedKey: "known", statusByKey: ["known": .known], ignoredKeys: [])

        XCTAssertEqual(state, .known)
    }

    func testLearningStatusReturnsLearning() {
        let state = resolver.state(forNormalizedKey: "learn", statusByKey: ["learn": .level3], ignoredKeys: [])

        XCTAssertEqual(state, .learning(level: .level3))
    }

    func testStateForWordNormalizesInput() {
        let state = resolver.state(for: "  KaNnAdA  ", statusByKey: ["kannada": .level2], ignoredKeys: [])

        XCTAssertEqual(state, .learning(level: .level2))
    }

    func testVisualStateMetadata() {
        XCTAssertEqual(WordLearningVisualState.new.accessibilityLabel, "new")
        XCTAssertEqual(WordLearningVisualState.ignored.accessibilityLabel, "ignored")
        XCTAssertEqual(WordLearningVisualState.known.accessibilityLabel, "known")
        XCTAssertEqual(WordLearningVisualState.learning(level: .level4).accessibilityLabel, "level 4")

        XCTAssertNil(WordLearningVisualState.new.levelBadge)
        XCTAssertNil(WordLearningVisualState.ignored.levelBadge)
        XCTAssertNil(WordLearningVisualState.known.levelBadge)
        XCTAssertEqual(WordLearningVisualState.learning(level: .level2).levelBadge, "2")

        XCTAssertTrue(WordLearningVisualState.new.isVisibleInSentenceList)
        XCTAssertTrue(WordLearningVisualState.learning(level: .level1).isVisibleInSentenceList)
        XCTAssertFalse(WordLearningVisualState.ignored.isVisibleInSentenceList)
        XCTAssertFalse(WordLearningVisualState.known.isVisibleInSentenceList)
    }
}
