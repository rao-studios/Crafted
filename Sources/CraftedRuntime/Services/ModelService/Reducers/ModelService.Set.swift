import CraftedCore
import Foundation
import Granite

extension ModelService {
    /// The single writer. The mutation is `ModelOps.apply`, tested as a value.
    public struct Set: GraniteReducer {
        public typealias Center = ModelService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                /// The disk read: every model's card and what this Mac has room for.
                case read([ModelStatus], MachineFit)
                case refreshing(Bool)
                /// A download's progress, 0 to 1.
                case progress(ModelKind, Double)
                /// The download `run` ended (finished, failed or cancelled); the next in the queue may start.
                case downloadEnded(run: UUID)
                case removing(ModelKind?)
                case notice(String?)
                case problem(String?)
                case reset
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            ModelOps.apply(meta.kind, to: &state)
        }

        public var thread: DispatchQueue? { .main }
    }
}
