import CraftedCore
import CraftedForge
import Foundation
import Granite
import GraniteAgents

extension ForgeService {
    /// The person's answers back into the run: an interpretation chosen, a steer instead, or a question answered.
    /// `reduce` marks what was answered (the cards or the question clear at once); the effect hands it to the run.
    public struct Answer: GraniteReducer {
        public typealias Center = ForgeService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Reply: Sendable {
                case choose(Int)
                case steer(String)
                case decide(String, DecisionAnswer)
            }
            public var id: String
            public var reply: Reply
            public init(id: String, reply: Reply) { self.id = id; self.reply = reply }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta, var run = state.live(meta.id), run.phase.isLive else { return }
            ForgeOps.answered(meta.reply, in: &run)
            state.run = run
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta, let run = ForgeService.live.get(meta.id) else { return .none }
            return .run {
                switch meta.reply {
                case .choose(let index): await run.choose(index)
                case .steer(let text): await run.steer(text)
                case .decide(let decision, let answer): await run.decide(decision, answer)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
