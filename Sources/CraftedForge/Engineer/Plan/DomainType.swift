import Foundation

/// A type the contracts name: a record (`struct`, its fields) or a choice (`enum`, its string cases). Code writes it,
/// Codable and Equatable, so a vector can make one from JSON and compare it.
public struct DomainType: Codable, Sendable, Equatable {
    public var name: String
    /// `struct` or `enum`.
    public var kind: String
    public var fields: [FieldSpec]
    public var cases: [String]
    public var note: String

    public init(name: String, kind: String = "struct", fields: [FieldSpec] = [], cases: [String] = [], note: String = "") {
        self.name = name; self.kind = kind; self.fields = fields; self.cases = cases; self.note = note
    }

    enum CodingKeys: String, CodingKey { case name, kind, fields, cases, note }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decode(String.self, forKey: .name)
        kind = try keyed.decodeIfPresent(String.self, forKey: .kind) ?? "struct"
        fields = try keyed.decodeIfPresent([FieldSpec].self, forKey: .fields) ?? []
        cases = try keyed.decodeIfPresent([String].self, forKey: .cases) ?? []
        note = try keyed.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
