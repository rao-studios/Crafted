import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension ModelService {
    /// The two models' state and the service's events: one reducer per verb, `set` the only writer.
    public struct Center: GraniteCenter {
        public init() {}

        /// PIN: never persisted (a `TransientState`): it mirrors the disk and is read again at launch.
        public struct State: TransientState {
            /// Each model's card, in catalog order (vision, coder).
            public var statuses: [ModelStatus] = ModelCatalog.all.map { ModelStatus.missing($0.kind) }
            /// Nil until the first read.
            public var fit: MachineFit?
            public var downloading: ModelDownload?
            /// What downloads after the one in flight, in catalog order.
            public var queue: [ModelKind] = []
            /// The download in flight, by its request's id: what `reduce` adopted, so its effect runs only that one.
            public var downloadRun: UUID?
            public var removing: ModelKind?
            public var isRefreshing = false
            /// Whether the disk was read at least once since launch.
            public var hasRead = false
            public var notice: String?
            public var problem: String?
            public init() {}

            public func status(_ kind: ModelKind) -> ModelStatus {
                statuses.first { $0.kind == kind } ?? .missing(kind)
            }

            public var visionReady: Bool { status(.vision).installed }
            public var coderReady: Bool { status(.coder).installed }
            public var bothReady: Bool { visionReady && coderReady }
            public var isDownloading: Bool { downloading != nil }

            /// Queued or downloading.
            public func isPending(_ kind: ModelKind) -> Bool { downloading?.kind == kind || queue.contains(kind) }
        }

        @Event public var set: Set.Reducer
        @Event public var refresh: Refresh.Reducer
        @Event public var download: Download.Reducer
        @Event public var cancel: Cancel.Reducer
        @Event public var remove: Remove.Reducer
        @Store public var state: State
    }
}
