import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

extension Onboarding {
    /// The window opened: this Mac (read once), the disk read.
    func appeared() async {
        _ = try? await environment.machine()
        await CraftedAppRoot.shared.waitForPreferences()
        await models.refresh()
    }

    func back() {
        if let previous = state.step.previous { _state.step.wrappedValue = previous }
    }

    func advance() {
        _state.stillMissing.wrappedValue = nil
        if let next = state.step.next { _state.step.wrappedValue = next }
    }

    /// Done: the root reads the disk again and opens Crafted only when it is ready (the launch waiting on the gate then
    /// shows the Workshop and puts this window away).
    func open() {
        Task { @MainActor in
            let readiness = await CraftedAppRoot.shared.finishOnboarding()
            if !readiness.isReady { _state.stillMissing.wrappedValue = OnboardingRules.stillMissing(readiness) }
        }
    }
}
