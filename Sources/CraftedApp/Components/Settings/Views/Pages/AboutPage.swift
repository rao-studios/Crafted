//  WHAT: Settings › About: a strip of the Saône quay, the mark, the Rao seal, which build is running (version, commit,
//        MD5, the packages it was built against), which models the forge runs on, and where Crafted keeps things.
//  IN:   BuildInfo.current, the runtime root's model choice.

import CraftedCore
import CraftedRuntime
import SwiftUI

struct AboutPage: View {
    let choice: ModelChoice
    private let build = BuildInfo.current

    var body: some View {
        SettingsPage(section: .about) {
            PaperLeaf(cornerRadius: 12) {
                ScenePainting(scene: .lyon, progress: nil, animated: false)
                    .frame(height: 120)
            }
            .frame(height: 120)
            CraftCard {
                VStack(spacing: .layer3) {
                    CraftedMark(size: 48)
                    Text("Crafted").craftType(.title).foregroundStyle(Color.craftInk)
                    Text("A folder in, a Craft agent out: made on this Mac by two on-device models.")
                        .craftType(.caption).foregroundStyle(Color.craftInkDim).multilineTextAlignment(.center)
                    BuildFooter()
                    if let seal = CraftedAssets.sealImage() {
                        Image(nsImage: seal).resizable().interpolation(.high).scaledToFit()
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Rao")
                    }
                }
                .padding(.vertical, .layer2)
                .frame(maxWidth: .infinity)
            }
            CraftCard {
                VStack(alignment: .leading, spacing: .layer4) {
                    FlowLayout(spacing: .layer5, lineSpacing: .layer3) {
                        CraftStat(value: build.version ?? "—", label: "Version")
                        CraftStat(value: build.build ?? "—", label: "Build")
                        CraftStat(value: choice.isScripted ? "Scripted" : "On-device", label: "Models")
                    }
                    VStack(alignment: .leading, spacing: .layer1) {
                        FieldRow(label: "Forge models", value: choice.title, mono: false)
                        FieldRow(label: "Crafted's folder", value: CraftFormat.tilde(CraftedHome.standard.root.path))
                        FieldRow(label: "Models folder", value: CraftFormat.tilde(ModelService.homePath))
                        ForEach(build.dependencies, id: \.name) { dependency in
                            FieldRow(label: dependency.name.prefix(1).uppercased() + dependency.name.dropFirst(), value: dependency.commit)
                        }
                    }
                }
            }
        }
    }
}

/// The line under About's name: "Crafted 0.1.0 (1) · built Nov 10 at 2:04 PM", and the commit and MD5 of the running
/// executable, so which copy is running is never a guess.
struct BuildFooter: View {
    private let build = BuildInfo.current
    @State private var md5: String?
    @State private var measured = false

    var body: some View {
        VStack(spacing: .layer1) {
            Text(summary).craftType(.caption).foregroundStyle(Color.craftInkDim).lineLimit(1)
            HStack(spacing: 0) {
                if let commit = build.commit { Text(BuildInfo.abbreviated(commit) + " · ") }
                Text(md5.map { "md5 " + BuildInfo.abbreviated($0) } ?? (measured ? "md5 unavailable" : "md5 …"))
            }
            .craftType(.codeTiny).foregroundStyle(Color.craftInkFaint)
        }
        .multilineTextAlignment(.center)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity)
        .task {
            md5 = await BuildInfo.executableMD5.value
            measured = true
        }
    }

    private var summary: String {
        if build.isDevelopment { return build.title + " · development build" }
        guard let builtAt = build.builtAt else { return build.title }
        return build.title + " · built " + builtAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
