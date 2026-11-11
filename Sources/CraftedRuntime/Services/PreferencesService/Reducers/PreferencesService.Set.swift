import CraftedCore
import Foundation
import Granite

extension PreferencesService {
    /// The single writer. The mutation is `PreferencesOps.apply`, tested as a value.
    public struct Set: GraniteReducer {
        public typealias Center = PreferencesService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                case role(CraftedRole?)
                case creditName(String)
                case creditLink(String)
                case appearance(AppearanceChoice)
                case reset
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            PreferencesOps.apply(meta.kind, to: &state)
        }

        public var thread: DispatchQueue? { nil }
    }
}
