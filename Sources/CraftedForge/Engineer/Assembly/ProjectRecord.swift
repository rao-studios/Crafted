import Foundation

/// What assembly says of the source project and the choice made: its folder's name, its title and licence, the
/// interpretation chosen, and the files the walk read. Kept in the run as project.json.
public struct ProjectRecord: Codable, Sendable, Equatable {
    public var folder: String
    public var title: String
    public var licence: String?
    public var card: InterpretationCard
    /// Every file and its verdict.
    public var files: [String: String]

    public init(folder: String, title: String, licence: String?, card: InterpretationCard, files: [String: String]) {
        self.folder = folder; self.title = title; self.licence = licence; self.card = card; self.files = files
    }
}
