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

    func testStableTopPaddingStaysCenteredWhenExtraContentFits() {
        let containerHeight: CGFloat = 420
        let baseHeight: CGFloat = 140
        let extraHeight: CGFloat = 70

        let centered = max(
            (containerHeight - baseHeight) / 2,
            ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding
        )
        let result = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
            containerHeight: containerHeight,
            baseContentHeight: baseHeight,
            extraContentHeight: extraHeight
        )

        XCTAssertEqual(result, centered, accuracy: 0.001)
    }

    func testStableTopPaddingOnlyMovesForOverflowAmount() {
        let containerHeight: CGFloat = 320
        let baseHeight: CGFloat = 140
        let extraHeight: CGFloat = 160

        let centered = max(
            (containerHeight - baseHeight) / 2,
            ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding
        )
        let freeSpaceBelowBase = containerHeight - centered - baseHeight
        let overflow = max(extraHeight - freeSpaceBelowBase, 0)
        let expected = max(ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding, centered - overflow)

        let result = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
            containerHeight: containerHeight,
            baseContentHeight: baseHeight,
            extraContentHeight: extraHeight
        )

        XCTAssertEqual(result, expected, accuracy: 0.001)
        XCTAssertLessThan(result, centered)
    }

    func testStableTopPaddingFallsBackToMinimumForNonPositiveContainer() {
        let result = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
            containerHeight: 0,
            baseContentHeight: 120,
            extraContentHeight: 80
        )

        XCTAssertEqual(result, ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding, accuracy: 0.001)
    }

    func testStableTopPaddingClampsWhenOverflowExceedsCenteredPadding() {
        let containerHeight: CGFloat = 240
        let baseHeight: CGFloat = 120
        let extraHeight: CGFloat = 400

        let result = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
            containerHeight: containerHeight,
            baseContentHeight: baseHeight,
            extraContentHeight: extraHeight
        )

        XCTAssertEqual(result, ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding, accuracy: 0.001)
    }
}
