import XCTest
@testable import LanguageReader

final class ReaderLayoutMetricsTests: XCTestCase {
    func testTopCanvasUsesUnifiedMode() {
        XCTAssertEqual(ReaderLayoutMetrics.topContentMode, .unifiedCanvas)
    }

    func testSentenceWordsSectionHeightClampsForSmallAndLargeScreens() {
        let small = ReaderLayoutMetrics.sentenceWordsSectionHeight(for: 220)
        let medium = ReaderLayoutMetrics.sentenceWordsSectionHeight(for: 700)
        let large = ReaderLayoutMetrics.sentenceWordsSectionHeight(for: 2000)

        XCTAssertEqual(small, ReaderLayoutMetrics.sentenceWordsSectionMinHeight)
        XCTAssertEqual(medium, 266, accuracy: 0.001)
        XCTAssertEqual(large, ReaderLayoutMetrics.sentenceWordsSectionMaxHeight)
    }

    func testTopInsetAndTopBarOffsetsStayTight() {
        XCTAssertEqual(ReaderLayoutMetrics.sentenceTopInsetExtra, 12)
        XCTAssertEqual(ReaderLayoutMetrics.wordModeTopPadding, 20)
        XCTAssertEqual(ReaderLayoutMetrics.topBarTopOffset, 0)
        XCTAssertLessThanOrEqual(ReaderLayoutMetrics.sentenceTopInsetExtra, 16)
    }

    func testReadingTextSizeIsUnifiedAcrossReaderSurfaces() {
        XCTAssertEqual(Theme.readingTextSize, 17)
    }

    func testWordsSectionDoesNotTakeMoreThanFortyPercentOfPage() {
        XCTAssertLessThanOrEqual(ReaderLayoutMetrics.sentenceWordsSectionRatio, 0.4)
    }

    func testTopCanvasPlacementStaysCenteredForStableTranslationReveal() {
        XCTAssertEqual(ReaderLayoutMetrics.sentenceTopCanvasPlacement, .centered)
    }
}
