import SwiftUI

/// A line along a tool window's foot: the last thing that happened, or what went wrong. Selectable,
/// so an error can be copied.
struct NoticeBar: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .craftType(.caption).foregroundStyle(tint)
            .lineLimit(3).truncationMode(.tail)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .layer4)
            .padding(.vertical, .layer2)
            .background(Color.craftRaised)
    }
}
