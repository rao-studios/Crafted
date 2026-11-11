import CraftedCore
import CraftedForge
import Foundation
import Granite
import GraniteAgents

extension ForgeService {
    /// The run and the downloads: one reducer per verb, `set` the only writer.
    public struct Center: GraniteCenter {
        public init() {}

        /// PIN: never persisted (a `TransientState`). A run's lasting record is its generation on disk; this mirrors the
        /// run in flight in this process.
        public struct State: TransientState {
            /// The run in flight, or the last one this launch.
            public var run: LiveRun?
            /// A start adopted before its run exists, by its request's id.
            public var starting: UUID?
            /// The generation being assembled and zipped, and its request's id.
            public var exporting: String?
            public var exportRequest: UUID?
            /// Each generation's last download this launch.
            public var exports: [String: ExportOutcome] = [:]
            public var problem: String?
            public init() {}

            /// Whether a run is going (or about to): what refuses a second start.
            public var isBusy: Bool { starting != nil || (run?.phase.isLive ?? false) }

            /// The live run of generation `id`, if that is the one in flight.
            public func live(_ id: String) -> LiveRun? {
                guard let run, run.id == id else { return nil }
                return run
            }
        }

        @Event public var set: Set.Reducer
        @Event public var start: Start.Reducer
        @Event public var answer: Answer.Reducer
        @Event public var cancel: Cancel.Reducer
        @Event public var export: Export.Reducer
        @Store public var state: State
    }
}
