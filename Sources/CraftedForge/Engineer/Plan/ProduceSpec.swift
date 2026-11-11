import Foundation

/// One thing a command produces: its product kind (`value`, `text`, `json`, `csv`, `file`, `report`, `series`,
/// `handoff`) and its name.
public struct ProduceSpec: Codable, Sendable, Equatable, Hashable {
    public static let kinds: Swift.Set<String> = ["say", "value", "text", "json", "csv", "file", "report", "series", "handoff"]
    /// Kinds that become a file, and so a `made` item.
    public static let fileKinds: Swift.Set<String> = ["text", "json", "csv", "file", "report", "series", "handoff"]

    public var kind: String
    public var name: String

    public init(kind: String, name: String) { self.kind = kind; self.name = name }
}
