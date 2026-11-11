//  WHAT: One of Crafted's two models, as a card: whether it is on this Mac, what it is and asks of the Mac, and
//        Download, Cancel or Remove. Settings › Models shows it twice, and the onboarding's models step the same two.
//  IN:   The model's status (ModelService), the download in flight, whether it is queued, this Mac's fit.
//  OUT:  `.modelCardDownload`, `.modelCardCancel`, `.modelCardRemove` (a ModelKind each), routed by the page.
//  PIN:  After Craft's VisionPanel and EmbeddingPanel: a status dot and word, a bar while it moves, the facts in a mono
//        grid, the actions at the foot, Remove behind a confirmation.
//  PIN:  REMOVE SAYS CRAFT SHARES THE COPY. The models live in ~/.rao/models, where Craft finds them too.

import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct ModelCard: View {
    let status: ModelStatus
    /// This model's download, when it is the one in flight.
    let download: ModelDownload?
    let queued: Bool
    let fit: MachineFit?
    let removing: Bool
    @Environment(\.graniteBubble) private var bubble
    @State private var confirmingRemove = false

    private var spec: ModelSpec { status.spec }

    var body: some View {
        VStack(alignment: .leading, spacing: .layer2) {
            SectionLabel(spec.kind == .vision ? "Vision model" : "Coding model")
            CraftCard {
                VStack(alignment: .leading, spacing: .layer3) {
                    title
                    progress
                    Text(spec.summary)
                        .craftType(.label).foregroundStyle(Color.craftInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if let shortfall = memoryShortfall { line(shortfall, tint: .craftWarning, symbol: "memorychip") }
                    if let shortfall = diskShortfall { line(shortfall, tint: .craftWarning, symbol: "internaldrive") }
                    if status.installed, !status.matchesPin {
                        line("A complete copy at another commit (\(status.commit.map { String($0.prefix(8)) } ?? "unrecorded")): used as it is, nothing is downloaded again.",
                             tint: .craftInkDim, symbol: "info.circle")
                    }
                    facts
                    actions
                }
            }
        }
        .confirmationDialog("Remove \(spec.name) from this Mac?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { remove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Craft uses this same copy in ~/.rao/models: removing it removes it for Craft too. Crafted can't make agents until it is downloaded again (\(String(format: "%.1f GB", spec.sizeGB))).")
        }
    }

    // MARK: - Parts

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: .layer2) {
            StatusDot(color: tint, hollow: !status.installed && download == nil, pulsing: download != nil)
            Text(spec.name).craftType(.detailTitle).foregroundStyle(Color.craftInk)
                .lineLimit(1).truncationMode(.middle).layoutPriority(1)
            Text(word).craftType(.identifier).foregroundStyle(tint).lineLimit(1).fixedSize()
            Spacer(minLength: .layer3)
            Text(String(format: "%.1f GB", spec.sizeGB)).craftType(.identifier).foregroundStyle(Color.craftInkDim)
                .lineLimit(1).fixedSize()
        }
        .help(spec.id)
    }

    @ViewBuilder
    private var progress: some View {
        if let download {
            VStack(alignment: .leading, spacing: .layer1) {
                ProgressView(value: download.fraction)
                Text(String(format: "Downloading · %.0f%% of %.1f GB", download.fraction * 100, spec.sizeGB))
                    .craftType(.caption).foregroundStyle(Color.craftInkDim)
            }
        } else if queued {
            line("Queued: downloads after the one in progress.", tint: .craftInkDim)
        }
    }

    private var facts: some View {
        var rows: [(String, String)] = [
            ("repository", spec.id + " @ " + spec.shortRevision),
            ("weights", "\(spec.quantization) · \(spec.license) · \(spec.publisher)"),
            ("memory", "a \(spec.minimumMemoryGB) GB Mac or more" + (fit.map { " · this Mac has \($0.physicalGB) GB" } ?? "")),
        ]
        if let path = status.path {
            rows.append(("on disk", (path as NSString).abbreviatingWithTildeInPath))
        } else if status.bytesOnDisk > 0 {
            rows.append(("fetched", String(format: "%.1f of %.1f GB: Download picks up from there", Double(status.bytesOnDisk) / 1e9, spec.sizeGB)))
        }
        return Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: .layer3, verticalSpacing: .layer1) {
            ForEach(rows, id: \.0) { row in
                GridRow {
                    Text(row.0).foregroundStyle(Color.craftInkDim).lineLimit(1).fixedSize()
                    Text(row.1).foregroundStyle(Color.craftInkSoft).textSelection(.enabled)
                        .lineLimit(2).truncationMode(.middle)
                        .help(row.1)
                }
            }
        }
        .craftType(.codeSmall)
    }

    private var actions: some View {
        HStack(spacing: .layer2) {
            if download != nil || queued {
                Button("Cancel") { cancel() }.buttonStyle(.craftQuiet)
            } else if status.installed {
                Button(removing ? "Removing…" : "Remove…") { confirmingRemove = true }
                    .buttonStyle(.craftQuiet)
                    .disabled(removing)
                    .help("Delete the model from this Mac (Craft's copy too)")
            } else {
                Button(status.bytesOnDisk > 0 ? "Resume download" : String(format: "Download (%.1f GB)", spec.sizeGB)) { downloadIt() }
                    .buttonStyle(CraftButtonStyle(kind: .prominent))
                    .disabled(memoryShortfall != nil || diskShortfall != nil)
                    .accessibilityIdentifier("models.\(spec.kind.rawValue).download")
            }
            Spacer()
            Link("Model card", destination: spec.cardURL).buttonStyle(.craftLink).craftType(.caption)
                .help(spec.cardURL.absoluteString)
        }
    }

    private func line(_ text: String, tint: Color, symbol: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: .layer2) {
            if let symbol { Image(systemName: symbol).font(.craftGlyph(.caption)).foregroundStyle(tint) }
            Text(text).craftType(.caption).foregroundStyle(tint).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - What it says

    private var memoryShortfall: String? {
        guard !status.installed else { return nil }
        return fit?.memoryShortfall(for: spec, allowLow: ProcessInfo.processInfo.environment["CRAFTED_ALLOW_LOW_MEMORY"] == "1")
    }

    private var diskShortfall: String? {
        guard !status.installed, download == nil else { return nil }
        return fit?.diskShortfall(remainingBytes: status.remainingBytes)
    }

    private var word: String {
        if download != nil { return "downloading" }
        if queued { return "queued" }
        if removing { return "removing" }
        return status.installed ? "on this Mac" : "not downloaded"
    }

    private var tint: Color {
        if download != nil || queued { return .craftTint }
        if status.installed { return .craftSuccess }
        return memoryShortfall != nil ? .craftWarning : .craftInkDim
    }

    // MARK: - What it sends

    private func downloadIt() { bubble(.modelCardDownload, spec.kind) }
    private func cancel() { bubble(.modelCardCancel, spec.kind) }
    private func remove() { bubble(.modelCardRemove, spec.kind) }
}

extension GraniteBubble.Name {
    static let modelCardDownload: Self = "ModelCard.download"
    static let modelCardCancel: Self = "ModelCard.cancel"
    static let modelCardRemove: Self = "ModelCard.remove"
}
