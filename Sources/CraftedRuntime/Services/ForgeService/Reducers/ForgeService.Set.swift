import CraftedCore
import CraftedForge
import Foundation
import Granite

extension ForgeService {
    /// The single writer. The mutation is `ForgeOps.apply`, tested as a value.
    public struct Set: GraniteReducer {
        public typealias Center = ForgeService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                /// A run exists: generation `id`, as `role`.
                case began(id: String, role: CraftedRole)
                /// The start `request` could not make a run.
                case startFailed(request: UUID, String)
                /// One of run `id`'s events, in order.
                case event(id: String, ForgeEvent)
                /// The consumer of run `id` ended (the stream finished).
                case ended(id: String)
                case exported(id: String, ExportOutcome)
                case problem(String?)
                case reset
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            ForgeOps.apply(meta.kind, to: &state)
        }

        public var thread: DispatchQueue? { .main }
    }
}
