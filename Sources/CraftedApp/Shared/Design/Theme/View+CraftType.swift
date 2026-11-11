import SwiftUI
import AppKit

extension View {
    /// Sets a role's face, tracking and leading.
    func craftType(_ role: CraftType) -> some View {
        font(role.font).kerning(role.kerning).lineSpacing(role.lineSpacing)
    }
}

extension Text {
    /// A role's face and tracking for one run of a concatenated `Text`; the leading is the whole text's.
    func craftRun(_ role: CraftType) -> Text {
        font(role.font).kerning(role.kerning)
    }
}
