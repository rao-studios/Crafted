import AppKit
import SwiftUI

/// A plain one-line field on the page colour, for answers typed inside a card. `content` lets
/// macOS offer what fits (an email, a one-time code); `role` sets the type (a code reads as code).
struct CraftTextField: View {
    let placeholder: String
    @Binding var text: String
    var content: NSTextContentType?
    var role: CraftType = .label

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .craftType(role)
            .textContentType(content)
            .craftFieldChrome()
    }
}
