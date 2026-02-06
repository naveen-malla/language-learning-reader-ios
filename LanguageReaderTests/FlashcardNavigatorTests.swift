import XCTest
@testable import LanguageReader

final class FlashcardNavigatorTests: XCTestCase {
    func testClampedIndex() {
        XCTAssertEqual(FlashcardNavigator.clampedIndex(0, count: 0), 0)
        XCTAssertEqual(FlashcardNavigator.clampedIndex(-1, count: 3), 0)
        XCTAssertEqual(FlashcardNavigator.clampedIndex(5, count: 3), 2)
        XCTAssertEqual(FlashcardNavigator.clampedIndex(1, count: 3), 1)
    }

    func testNextIndex() {
        XCTAssertEqual(FlashcardNavigator.nextIndex(current: 0, count: 0), 0)
        XCTAssertEqual(FlashcardNavigator.nextIndex(current: 0, count: 3), 1)
        XCTAssertEqual(FlashcardNavigator.nextIndex(current: 2, count: 3), 0)
        XCTAssertEqual(FlashcardNavigator.nextIndex(current: -4, count: 3), 1)
        XCTAssertEqual(FlashcardNavigator.nextIndex(current: 40, count: 3), 0)
    }
}
