//  WHAT: The app's composition root: holds the runtime root and a relay to every service the app acts through, boots
//        them, and is the façade AppKit (the delegate, the menus, the Dock) and the pages call for what is the
//        environment's: windows, folders, the onboarding gate, a run's start, a download's save panel.
//  IN:   The app delegate (launch, a folder on the Dock, reopen, quit), MainMenu, pages, the self-test.
//  OUT:  CraftedRuntimeRoot (the only file that names it besides the self-test), EnvironmentService, PreferencesService,
//        ModelService, LibraryService, ForgeService, the window controllers.
//  PIN:  NO MIRROR. Pages read the services under a RelayClock; nothing here copies their state. What the root keeps
//        is AppKit's (subscriptions, the onboarding's waiters).
//  PIN:  NOTHING HERE IS A RULE. Where a page goes, what a route shows, what a drop proposes: `EnvironmentOps` and
//        `WorkshopRules`, tested as values; this file decides through them and does the AppKit part.

import AppKit
import Combine
import CraftedCore
import CraftedForge
import CraftedRuntime
import Granite

@MainActor
final class CraftedAppRoot {
    /// The runtime root first: it quiets Granite's logger before any relay restores a store.
    static let shared: CraftedAppRoot = {
        _ = CraftedRuntimeRoot.shared
        return CraftedAppRoot()
    }()

    let runtime = CraftedRuntimeRoot.shared
    @Relay(.silence) var environment: EnvironmentService
    @Relay(.silence) var preferences: PreferencesService
    @Relay(.silence) var models: ModelService
    @Relay(.silence) var library: LibraryService
    @Relay(.silence) var forge: ForgeService

    /// Launch, waiting on the onboarding gate.
    var onboardingWaiters: [CheckedContinuation<Void, Never>] = []
    private var subscriptions = Swift.Set<AnyCancellable>()
    private var appearanceWatch: AnyCancellable?

    private init() {}

    // MARK: - Launch and quit

    /// Launch, before the onboarding gate: the residents the services work through, the appearance once the
    /// preferences have loaded, and what macOS says about the app.
    func launch() {
        runtime.boot()
        followActivation()
        followAppearance()
        Task { [weak self] in
            guard let self else { return }
            await self.waitForPreferences()
            self.applyAppearance(self.preferences.state.appearance)
        }
    }

    /// After the gate: the library read, the Workshop shown, then the folders held while the gate was shut.
    func startServices() {
        library.refreshSoon()
        models.refreshSoon()
    }

    /// A live run is cancelled so it is left `interrupted` (resumable from its ledger), not half-written.
    func shutdown() async {
        guard let run = forge.state.run, run.phase.isLive else { return }
        forge.cancel(run.id)
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if forge.state.run?.phase.isLive != true { break }
        }
    }

    /// Whether quitting now loses work: a run or a download in flight.
    var isBusy: Bool { forge.state.isBusy || models.state.isDownloading || forge.state.exporting != nil }

    /// The app's appearance, which every window, popover and alert inherits; nil (System) follows macOS.
    func applyAppearance(_ choice: AppearanceChoice) {
        NSApp.appearance = choice.appearance
        refreshDockIcon()
    }

    /// The preferences' store restores after the service exists: its first use waits for it (at most two seconds,
    /// then the defaults stand).
    func waitForPreferences() async {
        for _ in 0..<40 where !preferences.isLoaded {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// The options a run starts with: the credit from Settings › General.
    func runOptions(autoDecide: Bool = false, autoChoose: Int? = nil) -> ForgeOptions {
        ForgeOptions(credit: preferences.state.credit, creditURL: preferences.state.creditURL,
                     autoDecide: autoDecide, autoChoose: autoChoose)
    }

    // MARK: - AppKit

    private func followActivation() {
        environment.set(.activated(NSApp.isActive))
        let center = NotificationCenter.default
        center.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.environment.set(.activated(true))
                // Coming back reads the disk: a model removed in Craft, a generation deleted in Finder.
                self.models.refreshSoon()
                self.library.refreshSoon()
            }.store(in: &subscriptions)
        center.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in self?.environment.set(.activated(false)) }.store(in: &subscriptions)
    }

    /// A bare dev binary's Dock tile follows the appearance Crafted draws in.
    private func followAppearance() {
        guard CraftedAssets.isBareBinary else { return }
        NSApp.publisher(for: \.effectiveAppearance)
            .sink { [weak self] _ in self?.refreshDockIcon() }.store(in: &subscriptions)
    }

    private func refreshDockIcon() {
        guard CraftedAssets.isBareBinary, let icon = CraftedAssets.appIcon(dark: NSApp.effectiveAppearance.isDark) else { return }
        NSApp.applicationIconImage = icon
    }
}
