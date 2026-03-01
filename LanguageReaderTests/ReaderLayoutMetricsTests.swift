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
        XCTAssertEqual(medium, 238, accuracy: 0.001)
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

    func testTopCanvasPlacementPrefersTopAlignmentForLongSentences() {
        XCTAssertEqual(ReaderLayoutMetrics.sentenceTopCanvasPlacement, .topAligned)
    }

    func testStableTopPaddingUsesAdaptiveTopSpacingWhenContentFits() {
        let containerHeight: CGFloat = 420
        let baseHeight: CGFloat = 140
        let extraHeight: CGFloat = 70

        let freeSpace = max(containerHeight - baseHeight - extraHeight, 0)
        let adaptiveRange = max(
            ReaderLayoutMetrics.sentenceTopCanvasMaxTopPadding - ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding,
            0
        )
        let expected = ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding + min(
            adaptiveRange,
            freeSpace * ReaderLayoutMetrics.sentenceTopCanvasAdaptivePaddingRatio
        )
        let result = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
            containerHeight: containerHeight,
            baseContentHeight: baseHeight,
            extraContentHeight: extraHeight
        )

        XCTAssertEqual(result, expected, accuracy: 0.001)
        XCTAssertLessThanOrEqual(result, ReaderLayoutMetrics.sentenceTopCanvasMaxTopPadding)
    }

    func testStableTopPaddingFallsBackToMinimumWhenContentOverflows() {
        let containerHeight: CGFloat = 320
        let baseHeight: CGFloat = 140
        let extraHeight: CGFloat = 190

        let result = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
            containerHeight: containerHeight,
            baseContentHeight: baseHeight,
            extraContentHeight: extraHeight
        )

        XCTAssertEqual(result, ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding, accuracy: 0.001)
    }

    func testStableTopPaddingFallsBackToMinimumForNonPositiveContainer() {
        let result = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
            containerHeight: 0,
            baseContentHeight: 120,
            extraContentHeight: 80
        )

        XCTAssertEqual(result, ReaderLayoutMetrics.sentenceTopCanvasMinTopPadding, accuracy: 0.001)
    }

    func testStableTopPaddingNeverDropsBelowMinimumWithHeavyOverflow() {
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
