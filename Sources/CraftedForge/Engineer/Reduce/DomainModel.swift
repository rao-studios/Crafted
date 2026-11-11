import Foundation

/// What the project is about: its nature (business, creative, mixed), its kind, its entities and its terms.
public struct DomainModel: Codable, Sendable, Equatable {
    public struct Entity: Codable, Sendable, Equatable {
        public var name: String
        public var fields: [String]
        public var files: [String]

        enum CodingKeys: String, CodingKey { case name, fields, files }

        public init(from decoder: Decoder) throws {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            name = try keyed.decode(String.self, forKey: .name)
            fields = (try? keyed.decodeIfPresent([String].self, forKey: .fields)) ?? []
            files = (try? keyed.decodeIfPresent([String].self, forKey: .files)) ?? []
        }
    }

    public struct Term: Codable, Sendable, Equatable {
        public var term: String
        public var meaning: String
    }

    public var nature: String
    public var kind: String
    public var entities: [Entity]
    public var glossary: [Term]

    enum CodingKeys: String, CodingKey { case nature, kind, entities, glossary }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        nature = try keyed.decodeIfPresent(String.self, forKey: .nature) ?? "business"
        kind = try keyed.decodeIfPresent(String.self, forKey: .kind) ?? ""
        entities = try keyed.decodeIfPresent([Entity].self, forKey: .entities) ?? []
        glossary = try keyed.decodeIfPresent([Term].self, forKey: .glossary) ?? []
    }

    public var digest: String {
        "Nature: \(nature); kind: \(kind)\nEntities: " + entities.map { "\($0.name) (\($0.fields.joined(separator: ", ")))" }.joined(separator: "; ")
            + (glossary.isEmpty ? "" : "\nTerms: " + glossary.map { "\($0.term): \($0.meaning)" }.joined(separator: "; "))
    }
}
