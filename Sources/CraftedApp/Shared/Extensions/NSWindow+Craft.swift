import AppKit
import SwiftUI

extension NSWindow {
    /// A tool window's SwiftUI content, laid out in whatever size the window has.
    ///
    /// PIN: AppKit owns the size. A bare `NSHostingView` hands SwiftUI's minimum and ideal sizes to the
    /// window, so a list measured at its full height (the Frameworks window's seventeen frameworks, about
    /// 1,100 pt) became a minimum the window could not be resized below, taller than the screen. The
    /// floor is `contentMinSize`, from `CraftLayout`, as the project window's split view does.
    func hostCraft<Content: View>(_ content: Content) {
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        contentView = host
    }

    /// Opens centred at `ideal`, or where this window was last left, unless that frame no longer fits
    /// on the screen: a frame saved while a window could outgrow the screen comes back at `ideal`.
    func restoreFrame(named name: String, ideal: CGSize) {
        setContentSize(CraftLayout.fittedDefaultSize(ideal))
        center()
        setFrameAutosaveName(name)
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame,
              frame.height > visible.height || frame.width > visible.width else { return }
        setContentSize(CraftLayout.fittedDefaultSize(ideal))
        center()
    }
}
