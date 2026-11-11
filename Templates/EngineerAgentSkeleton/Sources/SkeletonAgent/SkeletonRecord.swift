import GraniteAgents

/// The agent's place in Granite's roster: an app or a runner that links this package finds the `skeletonword` agent
/// by this record, with nothing listed by hand.
@used @section("__DATA_CONST,__granite")
let skeletonRecord: GraniteRoster.Record = { GraniteRoster.record(SkeletonAgent.self) }
