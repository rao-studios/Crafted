import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: .layer4) {
            CraftedMark(size: 96, animated: false)
            Text("Welcome to Crafted").craftType(.pageTitle).foregroundStyle(Color.craftInk)
            Text("Drop a folder, and Crafted makes it into an agent for Craft: a designer's work becomes an agent that draws in their style; an engineer's project becomes an agent that does what the project does. Two models do it, here on this Mac. Nothing you drop leaves it.")
                .craftType(.body).foregroundStyle(Color.craftInkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Next: the two models. If Craft already downloaded them, they are found where they are.")
                .craftType(.caption).foregroundStyle(Color.craftInkDim)
        }
        .frame(maxWidth: CraftLayout.settingsMeasure)
        .frame(maxWidth: .infinity)
        .padding(.top, .layer3)
    }
}

/// Both models, their cards, Download both, and this Mac's line.
struct ModelsStep: View {
    let catalog: ModelService.Center.State
    let machine: DeviceProfile?
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: .layer4) {
            VStack(alignment: .leading, spacing: .layer1) {
                Text("Two models").craftType(.pageTitle).foregroundStyle(Color.craftInk)
                Text("A vision model reads a designer's pieces; a coding model walks a project and writes the agent. One is in memory at a time. They live in ~/.rao/models, the folder every Rao app shares.")
                    .craftType(.label).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
            }
            MachineLine(machine: machine, fit: catalog.fit)
            if catalog.bothReady {
                Label("Both are on this Mac. Continue.", systemImage: "checkmark.circle.fill")
                    .craftType(.label).foregroundStyle(Color.craftSuccess)
            } else if catalog.downloading == nil {
                Button(String(format: "Download both (%.1f GB)", Double(ModelCatalog.totalDownloadBytes) / 1e9)) { downloadBoth() }
                    .buttonStyle(.craft)
                    .disabled(catalog.fit.map { fit in ModelCatalog.all.contains { fit.memoryShortfall(for: $0, allowLow: Self.allowLow) != nil } } ?? false)
            }
            ModelCards(catalog: catalog)
            if let problem = catalog.problem {
                Text(problem).craftType(.caption).foregroundStyle(Color.craftError)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Text("It can take a while; leave this window open. A stopped download picks up where it stopped.")
                .craftType(.caption).foregroundStyle(Color.craftInkDim)
        }
    }

    static var allowLow: Bool { ProcessInfo.processInfo.environment["CRAFTED_ALLOW_LOW_MEMORY"] == "1" }

    private func downloadBoth() { bubble(.modelsStepDownloadBoth) }
}

/// Designer or engineer: what a dropped folder becomes. Settings › General changes it later.
struct RoleStep: View {
    let role: CraftedRole?

    var body: some View {
        VStack(alignment: .leading, spacing: .layer4) {
            VStack(alignment: .leading, spacing: .layer1) {
                Text("What do you make?").craftType(.pageTitle).foregroundStyle(Color.craftInk)
                Text("This decides what a folder you drop becomes. You can change it in Settings at any time.")
                    .craftType(.label).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(CraftedRole.allCases) { option in
                RoleRow(role: option, selected: option == role)
            }
        }
    }
}

struct RoleRow: View {
    let role: CraftedRole
    let selected: Bool
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        Button(action: choose) {
            RowCard(selected: selected) {
                HStack(alignment: .top, spacing: .layer3) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .font(.craftGlyph(.label))
                        .foregroundStyle(selected ? Color.craftTint : Color.craftInkDim)
                    Image(systemName: role.symbol).font(.craftGlyph(.heading)).foregroundStyle(Color.craftInkSoft)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: .layer1) {
                        Text(role.title).craftType(.labelStrong).foregroundStyle(Color.craftInk)
                        Text(role.blurb).craftType(.caption).foregroundStyle(Color.craftInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(role.title)\(selected ? ", selected" : "")")
    }

    private func choose() { bubble(.roleStepChoose, role) }
}

struct DoneStep: View {
    let role: CraftedRole?
    /// Why Open Crafted did not open it, when it did not.
    let stillMissing: String?

    var body: some View {
        VStack(spacing: .layer4) {
            Image(systemName: "checkmark.circle").font(.craftGlyph(.display, weight: .light)).foregroundStyle(Color.craftSuccess)
            Text("Crafted is ready").craftType(.pageTitle).foregroundStyle(Color.craftInk)
            Text((role ?? .designer).dropPrompt + " on the leaf, or on Crafted's icon in the Dock, and it becomes an agent you can download and list in Craft's store.")
                .craftType(.body).foregroundStyle(Color.craftInkSoft)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let stillMissing {
                Text(stillMissing).craftType(.caption).foregroundStyle(Color.craftWarning)
            }
        }
        .frame(maxWidth: CraftLayout.settingsMeasure)
        .frame(maxWidth: .infinity)
        .padding(.top, .layer5)
    }
}

extension GraniteBubble.Name {
    static let modelsStepDownloadBoth: Self = "ModelsStep.downloadBoth"
    static let roleStepChoose: Self = "RoleRow.choose"
}
