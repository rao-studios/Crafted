import SwiftUI
import AppKit

extension View {
    /// Craft's page with its ink and tint. Apply once at the root. The appearance is the app's
    /// (Settings › General, `CraftedAppRoot.applyAppearance`); every token follows it.
    func craftRoot() -> some View {
        self
            .tint(.craftTint)
            .foregroundStyle(Color.craftInk)
            .background(Color.craftBG)
    }
}
