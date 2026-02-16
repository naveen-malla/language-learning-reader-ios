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
    static let sentenceWordsSectionMaxHeight: CGFloat = 290
    static let sentenceWordsSectionRatio: CGFloat = 0.34
    static let sentenceHorizontalPadding: CGFloat = 6
    static let sentenceTopCanvasPlacement: SentenceTopCanvasPlacement = .centered
    static let sentenceTopCanvasMinTopPadding: CGFloat = 8
    static let sentenceTopCanvasAnchorRatio: CGFloat = 0.38

    static func sentenceWordsSectionHeight(for containerHeight: CGFloat) -> CGFloat {
        max(
            sentenceWordsSectionMinHeight,
            min(sentenceWordsSectionMaxHeight, containerHeight * sentenceWordsSectionRatio)
        )
    }

    static func sentenceTopCanvasStableTopPadding(
        containerHeight: CGFloat,
        baseContentHeight: CGFloat,
        extraContentHeight: CGFloat
    ) -> CGFloat {
        guard containerHeight > 0 else { return sentenceTopCanvasMinTopPadding }

        let clampedBase = max(baseContentHeight, 0)
        let clampedExtra = max(extraContentHeight, 0)
        let anchoredBasePadding = max(
            (containerHeight - clampedBase) * sentenceTopCanvasAnchorRatio,
            sentenceTopCanvasMinTopPadding
        )
        let availableBelowBase = max(containerHeight - anchoredBasePadding - clampedBase, 0)
        let overflow = max(clampedExtra - availableBelowBase, 0)

        return max(sentenceTopCanvasMinTopPadding, anchoredBasePadding - overflow)
    }
}
