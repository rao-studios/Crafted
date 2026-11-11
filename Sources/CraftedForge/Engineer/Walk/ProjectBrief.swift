import Foundation

/// What the project is, in at most 400 tokens: the prefix of every later ask about it.
public struct ProjectBrief: Codable, Sendable, Equatable {
    public var title: String
    public var summary: String
    public var purpose: String
    public var kind: String
    public var entry: [String]
    public var languages: [String]

    public init(title: String, summary: String, purpose: String = "", kind: String = "", entry: [String] = [], languages: [String] = []) {
        self.title = title; self.summary = summary; self.purpose = purpose; self.kind = kind; self.entry = entry; self.languages = languages
    }

    enum CodingKeys: String, CodingKey { case title, summary, purpose, kind, entry, languages }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        title = try keyed.decode(String.self, forKey: .title)
        summary = try keyed.decode(String.self, forKey: .summary)
        purpose = try keyed.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        kind = try keyed.decodeIfPresent(String.self, forKey: .kind) ?? ""
        entry = try keyed.decodeIfPresent([String].self, forKey: .entry) ?? []
        languages = try keyed.decodeIfPresent([String].self, forKey: .languages) ?? []
    }

    /// As every later prompt opens.
    public var prefix: String {
        "Project: \(title)\n\(summary)" + (purpose.isEmpty ? "" : "\nPurpose: \(purpose)")
    }
}
