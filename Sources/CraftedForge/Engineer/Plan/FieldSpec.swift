import Foundation

/// One stored property of a domain record.
public struct FieldSpec: Codable, Sendable, Equatable {
    public var name: String
    public var type: String
    public var note: String

    public init(name: String, type: String, note: String = "") { self.name = name; self.type = type; self.note = note }

    enum CodingKeys: String, CodingKey { case name, type, note }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decode(String.self, forKey: .name)
        type = try keyed.decode(String.self, forKey: .type)
        note = try keyed.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
