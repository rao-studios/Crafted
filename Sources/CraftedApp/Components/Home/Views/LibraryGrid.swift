import AppKit
import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

/// Every generation, newest change first, as tiles: icon, name, role, status, updated, last download.
struct LibraryGrid: View {
    let generations: [Generation]
    let listings: [String: AgentListing]
    let icons: [String: String]
    let iconRevision: Int
    let run: LiveRun?
    let exports: [String: ExportOutcome]

    var body: some View {
        VStack(alignment: .leading, spacing: .layer3) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Generations")
                if !generations.isEmpty {
                    Text(generations.count.formatted()).craftType(.caption).foregroundStyle(Color.craftInkDim)
                }
            }
            if generations.isEmpty {
                Text("Nothing yet. What you make is kept here: open one again, change its listing or icon, update it from its folder, and download it again.")
                    .craftType(.label).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: CraftLayout.Library.tileMin), spacing: .layer4)], spacing: .layer4) {
                    ForEach(generations) { generation in
                        GenerationTile(generation: generation, listing: listings[generation.id],
                                       icon: icons[generation.id], iconRevision: iconRevision,
                                       run: run?.id == generation.id ? run : nil)
                    }
                }
            }
        }
    }
}

/// One generation: open it with a click; its menu has Open, Update from Folder…, Show in Finder and Delete….
struct GenerationTile: View {
    let generation: Generation
    let listing: AgentListing?
    let icon: String?
    let iconRevision: Int
    let run: LiveRun?
    @Environment(\.graniteBubble) private var bubble
    @State private var hovering = false

    private var status: GenerationStatus { WorkshopRules.shownStatus(generation, run: run) }
    private var needsListing: Bool {
        guard status == .finished, let listing else { return false }
        return !ListingRules.problems(listing, role: generation.role).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .layer2) {
            HStack(alignment: .top, spacing: .layer3) {
                TileIcon(path: icon, revision: iconRevision, word: listing?.word ?? generation.title,
                         painting: status == .generating ? (run?.fraction ?? generation.fraction ?? 0) : nil)
                VStack(alignment: .leading, spacing: .hairline) {
                    Text(generation.title).craftType(.labelStrong).foregroundStyle(Color.craftInk)
                        .lineLimit(2).truncationMode(.tail)
                    Text(generation.role.title).craftType(.caption).foregroundStyle(Color.craftInkDim)
                }
                Spacer(minLength: 0)
                menu
            }
            Spacer(minLength: 0)
            statusLine
            if status == .generating {
                CraftMeter(fraction: run?.fraction ?? generation.fraction ?? 0)
            }
            Text(dates).craftType(.fine).foregroundStyle(Color.craftInkDim).lineLimit(1)
        }
        .padding(.layer3)
        .frame(maxWidth: .infinity, minHeight: CraftLayout.Library.tileHeight, maxHeight: CraftLayout.Library.tileHeight, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: CraftRadius.card, style: .continuous)
            .fill(hovering ? Color.craftRaised.opacity(0.9) : Color.craftRaised))
        .overlay(RoundedRectangle(cornerRadius: CraftRadius.card, style: .continuous).strokeBorder(Color.craftBorder))
        .contentShape(RoundedRectangle(cornerRadius: CraftRadius.card, style: .continuous))
        .onHover { hovering = $0 }
        .onTapGesture { open() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(generation.title), \(statusWord)")
    }

    private var menu: some View {
        Menu {
            Button("Open") { open() }
            Button("Update from Folder…") { update() }.disabled(status.isLive)
            Button("Show in Finder") { finder() }
            Divider()
            Button("Delete…", role: .destructive) { delete() }.disabled(status.isLive)
        } label: {
            Image(systemName: "ellipsis.circle").font(.craftGlyph(.body)).foregroundStyle(Color.craftInkDim)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: .layer2) {
            StatusDot(color: tint, hollow: status == .interrupted, pulsing: status.isLive)
            Text(statusWord).craftType(.captionStrong).foregroundStyle(tint).lineLimit(1)
            Spacer(minLength: 0)
            if status == .interrupted || status == .failed {
                Button("Resume") { resume() }.buttonStyle(.craftLink).craftType(.caption)
            }
        }
    }

    private var statusWord: String {
        switch status {
        case .generating:
            let percent = Int(((run?.fraction ?? generation.fraction ?? 0) * 100).rounded())
            return "Generating · \(percent)%"
        case .choosing: return "Choose one of three"
        case .waiting: return "Waiting for you"
        case .interrupted: return "Interrupted"
        case .failed: return "Failed"
        case .finished: return needsListing ? "Needs listing" : "Ready"
        }
    }

    private var tint: Color {
        switch status {
        case .generating, .choosing, .waiting: return .craftTint
        case .interrupted: return .craftWarning
        case .failed: return .craftError
        case .finished: return needsListing ? .craftWarning : .craftSuccess
        }
    }

    private var dates: String {
        var parts = ["Updated " + CraftFormat.ago(generation.updated)]
        if let last = generation.lastExport { parts.append("downloaded " + CraftFormat.ago(last)) }
        return parts.joined(separator: " · ")
    }

    private func open() { bubble(.tileOpen, generation.id) }
    private func update() { bubble(.tileUpdate, generation.id) }
    private func finder() { bubble(.tileFinder, generation.id) }
    private func resume() { bubble(.tileResume, generation.id) }
    private func delete() { bubble(.tileDelete, generation.id) }
}

/// A tile's picture: the agent's icon when it has one, the wash while it generates, else its word's first letter.
struct TileIcon: View {
    let path: String?
    let revision: Int
    let word: String
    /// While generating: how far the wash has come.
    let painting: Double?
    var size: CGFloat = CraftLayout.Library.tileIcon

    var body: some View {
        Group {
            if let painting {
                ScenePainting(scene: .gardens, progress: painting, animated: false)
            } else if let path, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFill()
            } else {
                ZStack {
                    Color.craftFill
                    Text(word.prefix(1).uppercased()).craftType(.title).foregroundStyle(Color.craftTint)
                }
            }
        }
        .id("\(path ?? "")#\(revision)")
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous).strokeBorder(Color.craftBorder, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
