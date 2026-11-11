import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

extension Models {
    var view: some View {
        let catalog = models.state
        return VStack(alignment: .leading, spacing: 0) {
            SettingsPage(section: .models, accessory: { rescan(catalog) }) {
                VStack(alignment: .leading, spacing: .layer5) {
                    MachineLine(machine: environment.state.machine, fit: catalog.fit)
                    if !catalog.bothReady, catalog.downloading == nil {
                        Button(String(format: "Download both (%.1f GB)", Double(ModelCatalog.totalDownloadBytes) / 1e9)) {
                            models.downloadAll()
                        }
                        .buttonStyle(.craft)
                    }
                    ModelCards(catalog: catalog)
                }
            }
            if let problem = catalog.problem {
                NoticeBar(text: problem, tint: .craftError)
            } else if let notice = catalog.notice {
                NoticeBar(text: notice, tint: .craftInkDim)
            }
        }
        .onBubble {
            On(.modelCardDownload, ModelKind.self) { models.download([$0]) }
            On(.modelCardCancel, ModelKind.self) { _ in models.cancelDownload() }
            On(.modelCardRemove, ModelKind.self) { kind in Task { await models.remove(kind) } }
        }
        .task {
            if environment.state.machine == nil { _ = try? await environment.machine() }
            await models.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }
                if models.state.downloading == nil { models.refreshSoon() }
            }
        }
    }

    /// Beside the page's title: the model folders read again.
    private func rescan(_ catalog: ModelService.Center.State) -> some View {
        Button { Task { await models.refresh() } } label: {
            if catalog.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise").font(.craftGlyph(.body)).foregroundStyle(Color.craftInkSoft)
            }
        }
        .buttonStyle(.plain)
        .disabled(catalog.isRefreshing)
        .help("Read the model folder again")
        .accessibilityLabel("Read the model folder again")
    }
}

/// Both cards, in catalog order (vision first): what the onboarding's models step shows too.
struct ModelCards: View {
    let catalog: ModelService.Center.State

    var body: some View {
        VStack(alignment: .leading, spacing: .layer4) {
            ForEach(ModelCatalog.all) { spec in
                ModelCard(status: catalog.status(spec.kind),
                          download: catalog.downloading?.kind == spec.kind ? catalog.downloading : nil,
                          queued: catalog.queue.contains(spec.kind), fit: catalog.fit,
                          removing: catalog.removing == spec.kind)
            }
        }
    }
}

/// This Mac, in one line: the chip, the memory, the disk free where the models live.
struct MachineLine: View {
    let machine: DeviceProfile?
    let fit: MachineFit?

    var body: some View {
        HStack(spacing: .layer2) {
            Image(systemName: "laptopcomputer").font(.craftGlyph(.caption)).foregroundStyle(Color.craftInkDim)
            Text(text).craftType(.caption).foregroundStyle(Color.craftInkDim).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var text: String {
        var parts = ["This Mac"]
        if let machine { parts.append(machine.chip) }
        if let memory = machine?.memoryGB ?? fit?.physicalGB { parts.append("\(memory) GB memory") }
        if let free = fit?.freeDiskBytes { parts.append(String(format: "%.0f GB free", Double(free) / 1e9)) }
        if let memory = machine?.memoryGB ?? fit?.physicalGB, memory < ModelCatalog.minimumMemoryGB {
            parts.append("the coding model needs \(ModelCatalog.minimumMemoryGB) GB")
        }
        return parts.joined(separator: " · ")
    }
}
