import CraftedCore
import Foundation
import Granite

extension LibraryService {
    /// The single writer. The mutation is `LibraryOps.apply`, tested as a value.
    public struct Set: GraniteReducer {
        public typealias Center = LibraryService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                /// The whole folder, read.
                case read(LibraryOps.Snapshot)
                /// One generation read again after an edit; nil record means it is gone.
                case one(id: String, LibraryOps.Entry?)
                case refreshing(Bool)
                case editing(String?)
                case problem(String?)
                case reset
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            LibraryOps.apply(meta.kind, to: &state)
        }

        public var thread: DispatchQueue? { .main }
    }
}
