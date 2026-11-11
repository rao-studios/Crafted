//  WHAT: The Workshop's window: the library (Home) and every generation's pages, one window for the app.
//  IN:   CraftedAppRoot (show), after the onboarding gate.
//  OUT:  The Workshop component.
//  PIN:  ONE WINDOW. Crafted makes one generation at a time; the route (EnvironmentService) says which page the window
//        shows, so a menu, the Dock and a page all move the same window.
//  PIN:  Closing it is not quitting while a run goes on (AppDelegate): the Dock brings it back on the same route.

import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private static var current: MainWindowController?

    static func show() {
        let controller = current ?? MainWindowController()
        current = controller
        NSApp.activate()
        controller.window?.makeKeyAndOrderFront(nil)
    }

    static var window: NSWindow? { current?.window }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CraftLayout.fittedDefaultSize(CraftLayout.workshop.ideal)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        super.init(window: window)
        window.title = "Crafted"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .craftBG
        window.tabbingMode = .disallowed
        window.contentMinSize = CraftLayout.workshop.floor
        window.delegate = self
        window.hostCraft(Workshop().craftRoot())
        window.restoreFrame(named: "CraftedWorkshop", ideal: CraftLayout.workshop.ideal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func windowWillClose(_ notification: Notification) { Self.current = nil }
}
