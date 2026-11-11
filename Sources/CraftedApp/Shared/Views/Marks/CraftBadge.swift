import SwiftUI

/// An uppercase capsule tag: FOCUS, CALLER, READ. Short tags keep their width; a tag that holds a
/// name (a project, a framework) is given a `maxWidth` and truncates in the middle, whole in its tooltip.
struct CraftBadge: View {
    let text: String
    var color: Color = .craftTint
    var maxWidth: CGFloat?

    var body: some View {
        let tag = Text(text.uppercased())
            .craftType(.badge)
            .foregroundStyle(color)
            .lineLimit(1)
        Group {
            if let maxWidth {
                tag.truncationMode(.middle).frame(maxWidth: maxWidth).help(text)
            } else {
                tag.fixedSize()
            }
        }
        .padding(CraftInset.badge)
        .background(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
        .fixedSize(horizontal: maxWidth == nil, vertical: true)
    }
}
