import SwiftUI

extension View {
    /// A one-line field's chrome: the page colour inside a hairline, at a control's insets. Every
    /// field Craft draws wears it (CraftTextField, CraftSecureField), so they line up in a form.
    func craftFieldChrome() -> some View {
        padding(EdgeInsets(top: CraftInset.control.top, leading: .layer2, bottom: CraftInset.control.bottom, trailing: .layer2))
            .background(Color.craftBG, in: RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous).strokeBorder(Color.craftBorder))
    }
}
