import AppKit
import CraftedCore
import CraftedRuntime
import Foundation

/// The onboarding gate: Crafted is not functional until both models are on disk and the person has said whether they
/// are a designer or an engineer. Until then the onboarding window is the app: the Workshop waits, and a folder
/// dropped on the Dock meanwhile is held and proposed once it is done.
///
/// PIN: COMPUTED FROM DISK AND THE STORED ROLE (`ModelReadiness.evaluate`) at launch and at Done, never a flag kept
/// across launches. Settings stays open throughout: About and Models need no gate.
extension CraftedAppRoot {
    /// Launch: returns at once when Crafted is ready; otherwise shows the onboarding and returns when it is done.
    func requireOnboarding() async {
        guard environment.state.onboarding != .open else { return }
        if await readiness().isReady {
            environment.set(.onboarding(.open))
            return
        }
        environment.set(.onboarding(.locked))
        OnboardingWindowController.show()
        await withCheckedContinuation { onboardingWaiters.append($0) }
    }

    /// What is still missing, read from disk and the preferences now.
    func readiness() async -> ModelReadiness {
        await waitForPreferences()
        _ = await models.refresh()
        return ModelReadiness.evaluate(vision: models.state.visionReady, coder: models.state.coderReady,
                                       role: preferences.state.role)
    }

    /// Every way into the Workshop asks first: true means not yet. The onboarding window comes forward when it is up.
    func holdsBack() -> Bool {
        switch environment.state.onboarding {
        case .open: return false
        case .checking: return true
        case .locked:
            OnboardingWindowController.show()
            return true
        }
    }

    /// Done: the disk is read again, and only a ready Crafted is let through. Answers what is still missing, if any.
    @discardableResult
    func finishOnboarding() async -> ModelReadiness {
        let readiness = await readiness()
        guard readiness.isReady else { return readiness }
        environment.set(.onboarding(.open))
        let waiting = onboardingWaiters
        onboardingWaiters = []
        waiting.forEach { $0.resume() }
        return readiness
    }

    /// After the gate: the services, the Workshop, then the folder held while it was shut (the first one is
    /// proposed; Crafted makes one generation at a time).
    func afterOnboarding() {
        MainRunLoop.perform { [self] in
            startServices()
            show(.workshop)
            dismiss(.onboarding)
            let held = environment.state.heldFolders
            environment.set(.heldTaken)
            if let first = held.first { propose(first) }
        }
    }
}
