import SwiftUI

/// A list row on the raised fill: a framework, a model, a probe hit. Brightens under the pointer and
/// carries an edge in the tint when selected.
struct RowCard<Content: View>: View {
    var selected = false
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        content
            .padding(.layer3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.craftFillTrace : Color.clear)
            .background(Color.craftRaised)
            .clipShape(RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous)
                .strokeBorder(selected ? Color.craftTint : Color.craftBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous))
            .onHover { hovering = $0 }
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
