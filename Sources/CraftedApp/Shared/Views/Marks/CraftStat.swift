import SwiftUI

/// A value over its label, for summary rows. Its own width; put several in a `FlowLayout` so a narrow
/// pane wraps them instead of clipping.
struct CraftStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: .hairline) {
            Text(value).craftType(.figure).foregroundStyle(Color.craftInk)
            Text(label).craftType(.fine).foregroundStyle(Color.craftInkDim)
        }
        .lineLimit(1)
        .fixedSize()
    }
}
