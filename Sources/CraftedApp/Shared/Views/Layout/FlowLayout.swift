import SwiftUI

/// An intrinsic-width wrapping layout (Ambient's `FlowLayout`): each subview is as wide
/// as its content, and a row that is full starts the next.
/// PIN: every placement lands on a whole point, so small text is drawn, not resampled.
/// PIN: no subview is wider than the row. One that would be is offered the row's width, so a long
/// value truncates or wraps inside the card instead of running past its edge.
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = .snug

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        var maxWidth: CGFloat = 0
        for (i, row) in rows.enumerated() {
            height += row.map(\.size.height).max() ?? 0
            if i > 0 { height += lineSpacing }
            maxWidth = max(maxWidth, row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1)))
        }
        // Up, not to nearest: rounding a measured height down clips its last pixel.
        return CGSize(width: proposal.width ?? maxWidth, height: height.rounded(.up))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (i, row) in computeRows(proposal: proposal, subviews: subviews).enumerated() {
            let rowHeight = row.map(\.size.height).max() ?? 0
            if i > 0 { y += lineSpacing }
            var x = bounds.minX
            for item in row {
                item.subview.place(at: CGPoint(x: x.rounded(), y: (y + (rowHeight - item.size.height) / 2).rounded()),
                                   proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[(subview: LayoutSubviews.Element, size: CGSize)]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[(subview: LayoutSubviews.Element, size: CGSize)]] = [[]]
        var width: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if width + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                width = 0
            }
            rows[rows.count - 1].append((subview, size))
            width += size.width + spacing
        }
        return rows
    }
}
