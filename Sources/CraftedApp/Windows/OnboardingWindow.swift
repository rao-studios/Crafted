import AppKit

/// The onboarding window: Esc does not close it, and neither does ⌘W. Quitting is the way out.
final class OnboardingWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {}
    override func performClose(_ sender: Any?) {}
}
