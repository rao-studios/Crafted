import CraftedCore
import Granite
import SwiftUI

/// Home's top line: the mark and name, the role pill (what a drop becomes), and Choose Folder… for those who do not drag.
struct HomeHeader: View {
    let role: CraftedRole
    let busy: Bool
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        HStack(spacing: .layer3) {
            CraftedMark(size: 26)
            Text("Crafted").craftType(.title).foregroundStyle(Color.craftInk)
            Menu {
                ForEach(CraftedRole.allCases) { option in
                    Button { choose(option) } label: {
                        Label(option.title, systemImage: option == role ? "checkmark" : option.symbol)
                    }
                }
            } label: {
                HStack(spacing: .layer1) {
                    Image(systemName: role.symbol).font(.craftGlyph(.small, weight: .semibold))
                    Text(role.title).craftType(.captionStrong)
                }
                .craftPill()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("What a folder you drop becomes. A run keeps the role it started with.")
            Spacer(minLength: .layer3)
            Button("Choose Folder…") { chooseFolder() }
                .buttonStyle(.craftQuiet)
                .disabled(busy)
        }
    }

    private func choose(_ role: CraftedRole) { bubble(.homeRole, role) }
    private func chooseFolder() { bubble(.homeChooseFolder) }
}

/// The drop leaf: Fourvière under its gold sky, the prompt in the sky. On drag-over, a ring of knots around the leaf
/// and a brass bloom pooling under the pointer.
struct DropLeaf: View {
    let prompt: String
    let targeted: Bool
    let pointer: UnitPoint

    var body: some View {
        PaperLeaf(cornerRadius: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ScenePainting(scene: .fourviere, progress: nil, animated: true)
                    if targeted {
                        BloomPool(tone: .brass, opacity: 0.55)
                            .frame(width: proxy.size.width * 0.42, height: proxy.size.width * 0.42)
                            .position(x: proxy.size.width * pointer.x, y: proxy.size.height * pointer.y)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                    VStack(alignment: .leading, spacing: .layer1) {
                        Text(targeted ? "Let go to make it an agent" : prompt)
                            .craftType(.pageTitle)
                            .foregroundStyle(WatercolourPalette.ink)
                        Text("Its files stay where they are. Crafted reads them here, on this Mac.")
                            .craftType(.label)
                            .foregroundStyle(WatercolourPalette.ink.opacity(0.7))
                    }
                    .padding(.layer5)
                    .frame(maxWidth: proxy.size.width * 0.55, alignment: .leading)
                    if targeted {
                        StitchedOutline(cornerRadius: 10, spacing: 9, dotRadius: 1.6, color: WatercolourPalette.brass)
                            .padding(.layer2)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: targeted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(prompt)
    }
}

/// What a dropped folder holds, as which role, and Start.
struct ProposalCard: View {
    let proposal: FolderProposal
    let role: CraftedRole
    let busy: Bool
    let problem: String?
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer3) {
                HStack(alignment: .firstTextBaseline, spacing: .layer2) {
                    Image(systemName: "folder").font(.craftGlyph(.heading)).foregroundStyle(Color.craftInkSoft)
                    Text(proposal.name).craftType(.detailTitle).foregroundStyle(Color.craftInk).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: .layer2)
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.craftGlyph(.caption)) }
                        .buttonStyle(.plain).foregroundStyle(Color.craftInkDim).help("Not this folder")
                }
                FlowLayout(spacing: .layer5, lineSpacing: .layer3) {
                    CraftStat(value: count(proposal.files), label: "Files")
                    CraftStat(value: count(proposal.images), label: "Pictures")
                    CraftStat(value: role.title, label: "As")
                }
                FieldRow(label: "Folder", value: CraftFormat.tilde(proposal.folder.path))
                Text(role.blurb).craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
                if let problem = proposal.problem ?? problem {
                    Text(problem).craftType(.caption).foregroundStyle(Color.craftError).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: .layer2) {
                    Button("Start") { start() }
                        .buttonStyle(.craft)
                        .keyboardShortcut(.defaultAction)
                        .disabled(busy || proposal.problem != nil || proposal.files == 0)
                        .accessibilityIdentifier("home.proposal.start")
                    Button("Cancel") { dismiss() }.buttonStyle(.craftQuiet)
                    if busy {
                        Text("A generation is running: one at a time, since one model fits in memory at a time.")
                            .craftType(.caption).foregroundStyle(Color.craftInkDim)
                    }
                }
            }
        }
    }

    private func count(_ value: Int?) -> String {
        guard let value else { return "…" }
        return (proposal.capped ? "more than " : "") + value.formatted()
    }

    private func start() { bubble(.proposalStart) }
    private func dismiss() { bubble(.proposalDismiss) }
}
