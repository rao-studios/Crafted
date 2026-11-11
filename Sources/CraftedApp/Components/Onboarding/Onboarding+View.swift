import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

extension Onboarding {
    var view: some View {
        let catalog = models.state
        return VStack(spacing: 0) {
            // The Saône quay as a band above the steps, washing in with the download's bytes.
            PaperLeaf(cornerRadius: 0) {
                ScenePainting(scene: .lyon, progress: OnboardingRules.washProgress(catalog), animated: true)
            }
            .frame(height: 132)
            StepBar(current: state.step)
                .padding(.horizontal, .layer5)
                .padding(.top, .layer4)
                .padding(.bottom, .layer4)
            Divider().overlay(Color.craftBorder)
            ScrollView {
                content(catalog)
                    .padding(.layer5)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            Divider().overlay(Color.craftBorder)
            footer(catalog)
                .padding(.horizontal, .layer5)
                .padding(.vertical, .layer3)
        }
        // PIN: fills the window rather than sizing it, so the footer never falls off the bottom.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.craftBG)
        .onBubble {
            On(.modelCardDownload, ModelKind.self) { models.download([$0]) }
            On(.modelCardCancel, ModelKind.self) { _ in models.cancelDownload() }
            On(.modelCardRemove, ModelKind.self) { kind in Task { await models.remove(kind) } }
            On(.modelsStepDownloadBoth) { models.downloadAll() }
            On(.roleStepChoose, CraftedRole.self) { preferences.set(.role($0)) }
        }
        .task { await appeared() }
    }

    @ViewBuilder
    private func content(_ catalog: ModelService.Center.State) -> some View {
        switch state.step {
        case .welcome:
            WelcomeStep()
        case .models:
            ModelsStep(catalog: catalog, machine: environment.state.machine)
        case .role:
            RoleStep(role: preferences.state.role)
        case .done:
            DoneStep(role: preferences.state.role, stillMissing: state.stillMissing)
        }
    }

    private func footer(_ catalog: ModelService.Center.State) -> some View {
        HStack(spacing: .layer3) {
            if state.step.previous != nil, state.step != .done {
                Button("Back") { back() }.buttonStyle(.craftQuiet)
            }
            Spacer(minLength: .layer3)
            if state.step == .done {
                Button("Open Crafted") { open() }.buttonStyle(.craft).keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") { advance() }
                    .buttonStyle(.craft).keyboardShortcut(.defaultAction)
                    .disabled(!OnboardingRules.canContinue(state.step, models: catalog, role: preferences.state.role))
            }
        }
    }
}
