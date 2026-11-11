//  WHAT: The onboarding's window: locked (no close button) until both models are on disk and a role is chosen.
//  IN:   CraftedAppRoot's onboarding gate (show, dismiss).
//  OUT:  The Onboarding component.
//  PIN:  A window, not a sheet: there is no other window yet. Ordered out at the end, never closed by
//        the person, so closing it is never "the last window closed".

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private static var current: OnboardingWindowController?

    static func show() {
        let controller = current ?? OnboardingWindowController()
        current = controller
        NSApp.activate()
        if controller.window?.isVisible == false { controller.window?.center() }
        controller.window?.makeKeyAndOrderFront(nil)
    }

    static func dismiss() {
        current?.window?.orderOut(nil)
        current = nil
    }

    private init() {
        let window = OnboardingWindow(
            contentRect: NSRect(origin: .zero, size: CraftLayout.onboarding.ideal),
            styleMask: [.titled, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        super.init(window: window)
        window.title = "Welcome to Crafted"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .craftBG
        window.tabbingMode = .disallowed
        window.contentMinSize = CraftLayout.onboarding.floor
        window.delegate = self
        window.hostCraft(Onboarding().craftRoot())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func windowShouldClose(_ sender: NSWindow) -> Bool { false }
}
