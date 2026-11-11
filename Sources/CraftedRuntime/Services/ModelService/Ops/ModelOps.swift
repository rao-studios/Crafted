//  WHAT: The model service's decisions as values: the writer's mutation, what a download request queues, what a
//        finished download says — and the one disk read every card and the gate rest on.
//  OUT:  ModelService's reducers; the onboarding and Settings › Models through the state.
//  PIN:  `apply`, `request` and `outcome` are pure. `read` reads the disk and nothing else.

import CraftedCore
import CraftedMLX
import Foundation

public enum ModelOps {
    public static func apply(_ kind: ModelService.Set.Meta.Kind, to state: inout ModelService.Center.State) {
        switch kind {
        case .read(let statuses, let fit):
            state.statuses = statuses
            state.fit = fit
            state.isRefreshing = false
            state.hasRead = true
            // Whatever is on disk now is no longer waiting to download.
            state.queue.removeAll { kind in statuses.contains { $0.kind == kind && $0.installed } }
        case .refreshing(let on):
            state.isRefreshing = on
        case .progress(let kind, let fraction):
            guard state.downloading?.kind == kind else { return }
            state.downloading?.fraction = min(max(fraction, 0), 1)
        case .downloadEnded(let run):
            guard state.downloadRun == run else { return }
            state.downloadRun = nil
            state.downloading = nil
        case .removing(let kind):
            state.removing = kind
        case .notice(let text):
            state.notice = text
            if text != nil { state.problem = nil }
        case .problem(let text):
            state.problem = text
            if text != nil { state.notice = nil }
        case .reset:
            state = .init()
        }
    }

    /// A download request: what is missing and allowed joins the queue in catalog order, and when nothing is in flight
    /// the request is adopted (its id) and takes the head of the queue. A model this Mac cannot hold, or has no disk
    /// for, is refused with the sentence that says why.
    public static func request(_ kinds: [ModelKind], run: UUID, allowLowMemory: Bool, in state: inout ModelService.Center.State) {
        var refusals: [String] = []
        for spec in ModelCatalog.all where kinds.contains(spec.kind) {
            let status = state.status(spec.kind)
            guard !status.installed, !state.isPending(spec.kind) else { continue }
            if let fit = state.fit {
                if let shortfall = fit.memoryShortfall(for: spec, allowLow: allowLowMemory) { refusals.append(shortfall); continue }
                let queued = state.queue.reduce(Int64(0)) { $0 + state.status($1).remainingBytes }
                    + (state.downloading.map { state.status($0.kind).remainingBytes } ?? 0)
                if let shortfall = fit.diskShortfall(remainingBytes: queued + status.remainingBytes) {
                    refusals.append("\(spec.name): \(shortfall)")
                    continue
                }
            }
            state.queue.append(spec.kind)
        }
        state.queue.sort { order($0) < order($1) }
        if !refusals.isEmpty { state.problem = refusals.joined(separator: " ") }
        guard state.downloading == nil, state.downloadRun == nil, !state.queue.isEmpty else { return }
        let next = state.queue.removeFirst()
        state.downloadRun = run
        state.downloading = ModelDownload(kind: next, fraction: 0)
        if refusals.isEmpty { state.problem = nil }
        state.notice = nil
    }

    /// What the card says when a download ends.
    public static func outcome(_ spec: ModelSpec, installed: Bool, cancelled: Bool, failure: String?) -> ModelService.Set.Meta.Kind {
        if installed { return .notice("\(spec.name) is on this Mac.") }
        if cancelled { return .notice("Stopped downloading \(spec.name). What was fetched is kept: Download picks up from there.") }
        if let failure { return .problem("\(spec.name) did not download: \(failure)") }
        return .problem("\(spec.name) is not complete on disk yet. Download again to finish it.")
    }

    static func order(_ kind: ModelKind) -> Int { ModelCatalog.all.firstIndex { $0.kind == kind } ?? 0 }

    // MARK: - The disk

    /// Each model's card from disk, and this Mac's memory and free disk.
    public static func read(home: ModelHome) -> ([ModelStatus], MachineFit) {
        let statuses = ModelCatalog.all.map { spec -> ModelStatus in
            if let located = ModelLocator.locate(spec, home: home) {
                return ModelStatus(kind: spec.kind, installed: true, path: located.path.path, commit: located.commit,
                                   bytesOnDisk: located.bytes, remainingBytes: 0)
            }
            let partial = ModelLocator.bytesOnDisk(home.folder(spec))
            return ModelStatus(kind: spec.kind, installed: false, bytesOnDisk: partial,
                               remainingBytes: max(0, spec.downloadBytes - partial))
        }
        return (statuses, MemoryPlan.read().machineFit(home: home))
    }
}
