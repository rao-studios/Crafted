import Foundation

/// A model-written body that passed its ladder, kept in the run by the template's path: placed byte for byte by every
/// assembly, never stamped, never edited.
public struct SlotBody: Codable, Sendable, Equatable {
    public var path: String
    public var text: String
    /// What wrote it: the unit or command, the strategy and the attempt.
    public var by: String

    public init(path: String, text: String, by: String) { self.path = path; self.text = text; self.by = by }

    /// The artefact name it is kept under.
    public static func artefact(_ path: String) -> String {
        "slots/" + path.replacingOccurrences(of: "/", with: "__") + ".json"
    }
}
