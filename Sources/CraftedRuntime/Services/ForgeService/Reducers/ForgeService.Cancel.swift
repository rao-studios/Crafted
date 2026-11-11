import CraftedCore
import CraftedForge
import Foundation
import Granite
import GraniteAgents

extension ForgeService {
    /// Stops a run. The run says `cancelled` itself (and its record turns `interrupted`), which the consumer carries into
    /// state; with no run to ask, the consumer is cancelled through the registry.
    public struct Cancel: GraniteReducer {
        public typealias Center = ForgeService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public var id: String
            public init(id: String) { self.id = id }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta, state.live(meta.id)?.phase.isLive == true else { return }
            state.run?.cancelling = true
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            if let run = ForgeService.live.get(meta.id) {
                return .run { await run.cancel() }
            }
            // Only a consumer that exists: a tombstone left for an id with none would cancel that generation's next run.
            if ForgeService.runs.isRunning(meta.id) { ForgeService.runs.cancel(meta.id) }
            return .none
        }

        public var thread: DispatchQueue? { .main }
    }
}
