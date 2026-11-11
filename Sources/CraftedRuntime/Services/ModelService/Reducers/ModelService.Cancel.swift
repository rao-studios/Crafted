import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension ModelService {
    /// Stops the download in flight and empties the queue. The run's own end reads the disk and clears its id; what was
    /// fetched stays, so the next Download resumes it.
    public struct Cancel: GraniteReducer {
        public typealias Center = ModelService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public init() {}
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            state.queue = []
        }

        public func effect(state: Center.State) -> GraniteEffect {
            if let run = state.downloadRun { ModelService.runs.cancel("download/\(run)") }
            return .none
        }

        public var thread: DispatchQueue? { .main }
    }
}
