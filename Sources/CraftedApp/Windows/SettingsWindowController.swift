import AppKit
import SwiftUI

/// Settings: one window for the whole app — who you are, the models, this build. Ambient's
/// window, in Craft's palette: the sidebar runs under the traffic lights.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var current: SettingsWindowController?

    /// Opens Settings on the page the environment holds (`CraftedAppRoot.show(.settings(_:))` sets it first,
    /// so a deep link lands whether or not the window was open).
    static func show() {
        let controller = current ?? SettingsWindowController()
        current = controller
        NSApp.activate()
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CraftLayout.fittedDefaultSize(CraftLayout.settings.ideal)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        super.init(window: window)
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .craftBG
        window.tabbingMode = .disallowed
        window.contentMinSize = CraftLayout.settings.floor
        window.delegate = self
        window.hostCraft(Settings().craftRoot())
        window.restoreFrame(named: "CraftedSettings", ideal: CraftLayout.settings.ideal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Every opening builds Settings afresh: what a page reads, it reads again.
    func windowWillClose(_ notification: Notification) { Self.current = nil }
}
