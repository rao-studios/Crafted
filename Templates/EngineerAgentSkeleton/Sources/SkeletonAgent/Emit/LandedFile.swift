import Foundation

/// A planned file once it is on disk: where it landed, absolute, and whether it replaced one.
struct LandedFile: Sendable {
    var planned: PlannedFile
    /// Absolute.
    var path: String
    var existed: Bool
}
