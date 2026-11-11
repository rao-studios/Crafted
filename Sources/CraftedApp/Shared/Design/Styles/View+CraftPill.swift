import SwiftUI

extension View {
    /// A one-line capsule under a reply or a card: its provenance, its reference, what it could not find.
    func craftPill(tint: Color = .craftInkDim, fill: Color = .craftFillTrace, hovering: Bool = false) -> some View {
        self
            .lineLimit(1)
            .foregroundStyle(hovering ? Color.craftInk : tint)
            .padding(.horizontal, .layer2)
            .padding(.vertical, .layer1)
            .background(Capsule().fill(hovering ? Color.craftFill : fill))
            .contentShape(Capsule())
    }
}
