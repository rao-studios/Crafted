import Foundation

/// A file an emitter means to write: where (relative to the project), its bytes, the kind and name it is made as, and
/// the standard it follows when it has its own (`craft-timeseries/1`).
struct PlannedFile: Sendable {
    var path: String
    var data: Data
    var kind: String
    var name: String
    var what: String
    var schema: String?
}
