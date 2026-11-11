import Foundation

/// One argument of a command: its name (a field of the flat input), its type, its values when a choice, whether the
/// command needs it, and the note shown beside the field.
///
/// Types: `string`, `integer`, `number`, `boolean`, `choice`, `path` (a file inside the project), `[string]`, `[number]`.
public struct ArgumentSpec: Codable, Sendable, Equatable {
    public static let types: Swift.Set<String> = ["string", "integer", "number", "boolean", "choice", "path", "[string]", "[number]"]

    public var name: String
    public var type: String
    public var values: [String]?
    public var required: Bool
    public var note: String

    public init(name: String, type: String, values: [String]? = nil, required: Bool = false, note: String = "") {
        self.name = name; self.type = type; self.values = values; self.required = required; self.note = note
    }

    enum CodingKeys: String, CodingKey { case name, type, values, required, note }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decode(String.self, forKey: .name)
        type = try keyed.decode(String.self, forKey: .type)
        values = try keyed.decodeIfPresent([String].self, forKey: .values)
        required = try keyed.decodeIfPresent(Bool.self, forKey: .required) ?? false
        note = try keyed.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
