import SwiftUI

/// Small uppercase section label.
struct SectionLabel: View {
    let text: String
    var color: Color = Color.craftInkMuted
    init(_ text: String, color: Color = Color.craftInkMuted) { self.text = text; self.color = color }

    var body: some View {
        Text(text.uppercased())
            .craftType(.section)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
