import SwiftUI

/// A label and its value on one line: a path, a port, a version. The value truncates in the middle and
/// shows whole in its tooltip.
struct FieldRow: View {
    let label: String
    let value: String
    var mono = true
    /// The label column, so a card's rows line up; a row of its own on a card (`AccountPlanRow`) takes the same.
    static let labelColumn: CGFloat = 110
    var labelWidth: CGFloat = FieldRow.labelColumn

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .layer3) {
            Text(label).craftType(.caption).foregroundStyle(Color.craftInkDim)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            Text(value).craftType(mono ? .identifier : .caption).foregroundStyle(Color.craftInkSoft)
                .lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled)
                .help(value)
        }
    }
}
