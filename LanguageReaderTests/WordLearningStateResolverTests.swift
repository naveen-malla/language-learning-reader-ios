import XCTest
@testable import LanguageReader

final class WordLearningStateResolverTests: XCTestCase {
    private let resolver = WordLearningStateResolver(normalizer: TextNormalizer())

    func testReturnsIgnoredBeforeStatus() {
        let state = resolver.state(
            forNormalizedKey: "ಮನೆ",
            statusByKey: ["ಮನೆ": .level3],
            ignoredKeys: ["ಮನೆ"]
        )

        XCTAssertEqual(state, .ignored)
        XCTAssertFalse(state.isVisibleInSentenceList)
    }

    func testReturnsKnownForKnownStatus() {
        let state = resolver.state(
            forNormalizedKey: "ಮನೆ",
            statusByKey: ["ಮನೆ": .known],
            ignoredKeys: []
        )

        XCTAssertEqual(state, .known)
        XCTAssertFalse(state.isVisibleInSentenceList)
    }

    func testReturnsLearningForTrackedLearningStatus() {
        let state = resolver.state(
            forNormalizedKey: "ಮನೆ",
            statusByKey: ["ಮನೆ": .level3],
            ignoredKeys: []
        )

        XCTAssertEqual(state, .learning(level: .level3))
        XCTAssertEqual(state.levelBadge, "3")
        XCTAssertTrue(state.isVisibleInSentenceList)
    }

    func testReturnsNewWhenStatusMissing() {
        let state = resolver.state(
            for: "  ಹೊಸದು ",
            statusByKey: [:],
            ignoredKeys: []
        )

        XCTAssertEqual(state, .new)
        XCTAssertTrue(state.isVisibleInSentenceList)
    }

    func testNormalizesInputWordBeforeLookup() {
        let state = resolver.state(
            for: "  HELLO ",
            statusByKey: ["hello": .level2],
            ignoredKeys: []
        )

        XCTAssertEqual(state, .learning(level: .level2))
    }

    func testReturnsNewForEmptyNormalizedKey() {
        let state = resolver.state(
            forNormalizedKey: "   ",
            statusByKey: ["": .level1],
            ignoredKeys: [""]
        )

        XCTAssertEqual(state, .new)
        XCTAssertTrue(state.isVisibleInSentenceList)
    }

    func testKnownOverridesLearningLevelBadge() {
        let state = resolver.state(
            forNormalizedKey: "ಮನೆ",
            statusByKey: ["ಮನೆ": .known],
            ignoredKeys: []
        )

        XCTAssertNil(state.levelBadge)
    }
}
