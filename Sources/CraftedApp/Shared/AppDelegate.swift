//  WHAT: AppKit's entry: launch, folders opened on the Dock icon, the last window closing, reopen, quit, and the menus'
//        actions. Every one is a call into the app root.
//  IN:   NSApplication; MainMenu's actions.
//  OUT:  CraftedAppRoot; SelfTest when CRAFTED_SELFTEST is set.

import AppKit
import CraftedCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let root = CraftedAppRoot.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        if SelfTest.isRequested {
            root.launch()
            SelfTest.run(root)
            return
        }
        MainMenu.install()
        root.launch()
        // Crafted works only with its two models on disk and a role chosen: the onboarding first, when either is missing.
        let root = root
        Task {
            await root.requireOnboarding()
            root.afterOnboarding()
        }
    }

    /// A folder dropped on the Dock icon, or opened with Crafted from Finder (Info.plist's `public.folder` type).
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !SelfTest.isRequested else { return }
        root.open(urls)
    }

    /// Quits with nothing at work; with a run or a download going, stays (the Dock brings the Workshop back).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !SelfTest.isRequested && !root.isBusy
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { root.show(root.environment.state.onboarding == .open ? .workshop : .onboarding) }
        return false
    }

    /// A live run is stopped so it is left resumable before the app goes.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard root.forge.state.run?.phase.isLive == true else { return .terminateNow }
        Task {
            await root.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc func newGeneration(_ sender: Any?) { root.chooseFolder() }
    @objc func showLibrary(_ sender: Any?) {
        guard !root.holdsBack() else { return }
        root.showLibrary()
    }
    @objc func showModels(_ sender: Any?) { root.show(.settings(.models)) }
    @objc func showSettings(_ sender: Any?) { root.show(.settings(nil)) }
    @objc func showAbout(_ sender: Any?) { root.show(.settings(.about)) }
}
