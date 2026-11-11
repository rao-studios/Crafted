import CraftedCore
import CraftedMLX
import Foundation
import Granite
import GraniteAgents

extension ModelService {
    /// Downloads the models asked for, one at a time in catalog order, at their pinned commits.
    ///
    /// PIN: A REQUEST IS ADOPTED BY ID. `reduce` queues what is missing and, only when nothing is in flight, adopts this
    /// request's id and takes the queue's head; the effect starts a download only when the committed state carries its
    /// id. The end of each download sends an empty request, which takes the next one off the queue.
    public struct Download: GraniteReducer {
        public typealias Center = ModelService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public var id: UUID
            public var kinds: [ModelKind]
            public init(id: UUID, kinds: [ModelKind]) { self.id = id; self.kinds = kinds }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            ModelOps.request(meta.kinds, run: meta.id, allowLowMemory: MemoryPlan.allowsLowMemory, in: &state)
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta, state.downloadRun == meta.id, let current = state.downloading else { return .none }
            let models = Live.service(ModelService.self)
            let home = ModelService.home
            let run = meta.id
            let kind = current.kind
            let key = "download/\(run)"
            return .run {
                let task = Task(priority: .userInitiated) {
                    let spec = ModelCatalog.spec(kind)
                    let throttle = ProgressThrottle()
                    var failure: String?
                    do {
                        _ = try await ModelDownloader.download(spec, home: home) { fraction in
                            if throttle.shouldSend(fraction) { models.set(.progress(kind, fraction)) }
                        }
                    } catch {
                        failure = error.localizedDescription
                    }
                    let cancelled = Task.isCancelled || ModelService.runs.isCancelled(key)
                    // The disk says whether it is there: a cancelled snapshot may have returned normally.
                    let (statuses, fit) = ModelOps.read(home: home)
                    models.set(.read(statuses, fit))
                    let installed = statuses.first { $0.kind == kind }?.installed ?? false
                    models.set(ModelOps.outcome(spec, installed: installed, cancelled: cancelled, failure: failure))
                    models.set(.downloadEnded(run: run))
                    ModelService.runs.finish(key)
                    // The next in the queue, if any.
                    models.download([])
                }
                if !ModelService.runs.register(key, task) { task.cancel() }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}

/// A download's progress, at most every 100 ms or every half percent: the Hub reports far more often than a bar moves.
final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var lastFraction = -1.0
    private var lastTime = Date.distantPast

    func shouldSend(_ fraction: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        guard fraction >= 1 || fraction - lastFraction >= 0.005 || now.timeIntervalSince(lastTime) >= 0.1 else { return false }
        lastFraction = fraction
        lastTime = now
        return true
    }
}
