import SwiftUI

extension View {
    /// The small dim line under a control that says what it does.
    func settingsCaption() -> some View {
        craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
    }
}
