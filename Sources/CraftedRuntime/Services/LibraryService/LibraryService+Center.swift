import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension LibraryService {
    /// The generations and their listings: `set` the only writer.
    public struct Center: GraniteCenter {
        public init() {}

        /// PIN: never persisted (a `TransientState`): a read of the generations folder, made again at launch.
        public struct State: TransientState {
            /// Newest change first.
            public var generations: [Generation] = []
            /// Each generation's listing.json, by id.
            public var listings: [String: AgentListing] = [:]
            /// Each generation's icon.png when it has one, by id.
            public var icons: [String: String] = [:]
            /// Bumped whenever an icon file changes, so a tile drawing the same path reads it again.
            public var iconRevision = 0
            public var isRefreshing = false
            /// Whether the folder was read at least once since launch.
            public var hasRead = false
            /// The edit in flight, by generation id.
            public var editing: String?
            public var problem: String?
            public init() {}

            public func generation(_ id: String) -> Generation? { generations.first { $0.id == id } }
        }

        @Event public var set: Set.Reducer
        @Event public var refresh: Refresh.Reducer
        @Event public var edit: Edit.Reducer
        @Store public var state: State
    }
}
