import AppKit

// A windowed app: Dock tile, main menu. AppKit owns the process, SwiftUI every surface.
// CRAFTED_SELFTEST=<folder> runs the app's services headlessly through the root (SelfTest) and exits.
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(SelfTest.isRequested ? .prohibited : .regular)
withExtendedLifetime(delegate) {
    app.run()
}
