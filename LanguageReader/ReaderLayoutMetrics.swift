import CoreGraphics

enum SentenceTopContentMode {
    case unifiedCanvas
}

enum SentenceTopCanvasPlacement {
    case centered
}

struct ReaderLayoutMetrics {
    static let topContentMode: SentenceTopContentMode = .unifiedCanvas

    static let wordModeTopPadding: CGFloat = 20
    static let sentenceTopInsetExtra: CGFloat = 12
    static let sentenceBottomInsetExtra: CGFloat = 56
    static let topBarTopOffset: CGFloat = 0

    static let sentenceWordsSectionMinHeight: CGFloat = 200
    static let sentenceWordsSectionMaxHeight: CGFloat = 320
    static let sentenceWordsSectionRatio: CGFloat = 0.38
    static let sentenceHorizontalPadding: CGFloat = 6
    static let sentenceTopCanvasPlacement: SentenceTopCanvasPlacement = .centered

    static func sentenceWordsSectionHeight(for containerHeight: CGFloat) -> CGFloat {
        max(
            sentenceWordsSectionMinHeight,
            min(sentenceWordsSectionMaxHeight, containerHeight * sentenceWordsSectionRatio)
        )
    }
}
