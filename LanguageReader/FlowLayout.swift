import SwiftUI

struct FlowLayout: Layout {
    var itemSpacing: CGFloat = 0
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentLineWidth == 0 ? size.width : currentLineWidth + itemSpacing + size.width

            if nextWidth > maxWidth, currentLineWidth > 0 {
                maxLineWidth = max(maxLineWidth, currentLineWidth)
                totalHeight += currentLineHeight + lineSpacing
                currentLineWidth = size.width
                currentLineHeight = size.height
            } else {
                currentLineWidth = nextWidth
                currentLineHeight = max(currentLineHeight, size.height)
            }
        }

        maxLineWidth = max(maxLineWidth, currentLineWidth)
        totalHeight += currentLineHeight

        return CGSize(width: maxLineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextX = x == bounds.minX ? x + size.width : x + itemSpacing + size.width

            if nextX > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x = x == bounds.minX ? x + size.width : x + itemSpacing + size.width
            lineHeight = max(lineHeight, size.height)
        }
    }
}
