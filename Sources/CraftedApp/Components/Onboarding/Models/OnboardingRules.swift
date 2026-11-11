import CraftedCore
import CraftedRuntime
import Foundation

/// The onboarding's decisions as values: when Continue is on, how far the band has washed in, what Done says.
enum OnboardingRules {
    /// Continue is on when the step has what the next one needs: both models on disk with nothing downloading, a role.
    static func canContinue(_ step: OnboardingStep, models: ModelService.Center.State, role: CraftedRole?) -> Bool {
        switch step {
        case .welcome, .done: return true
        case .models: return models.bothReady && models.downloading == nil
        case .role: return role != nil
        }
    }

    /// The band over the steps washes in with the download's bytes: what is on disk of the two models' total, the
    /// one in flight counted by its fraction. Nil (fully painted) once both are here.
    static func washProgress(_ models: ModelService.Center.State) -> Double? {
        guard !models.bothReady else { return nil }
        let total = Double(ModelCatalog.totalDownloadBytes)
        guard total > 0 else { return nil }
        var done = 0.0
        for spec in ModelCatalog.all {
            let status = models.status(spec.kind)
            if status.installed {
                done += Double(spec.downloadBytes)
            } else if let download = models.downloading, download.kind == spec.kind {
                done += Double(spec.downloadBytes) * download.fraction
            } else {
                done += Double(min(status.bytesOnDisk, spec.downloadBytes))
            }
        }
        return min(max(done / total, 0.02), 1)
    }

    /// Done could not open Crafted: the sentence that says what is still missing.
    static func stillMissing(_ readiness: ModelReadiness) -> String? {
        guard !readiness.isReady else { return nil }
        var missing: [String] = []
        if readiness.gaps.contains(.vision) { missing.append("the vision model") }
        if readiness.gaps.contains(.coder) { missing.append("the coding model") }
        if readiness.gaps.contains(.role) { missing.append("your role") }
        return "Still missing: " + missing.joined(separator: " and ") + "."
    }
}
