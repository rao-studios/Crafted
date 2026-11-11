import Foundation

/// One command of `commands.json`: its name, what it does, the use cases it rests on, its arguments, what it
/// produces, the units it uses, and how its products are presented when the call does not say.
public struct CommandSpec: Codable, Sendable, Equatable {
    public var name: String
    public var summary: String
    public var usecases: [String]
    public var args: [ArgumentSpec]
    public var produces: [ProduceSpec]
    public var uses: [String]
    /// output, canvas or context.
    public var present: String

    public init(name: String, summary: String, usecases: [String] = [], args: [ArgumentSpec] = [], produces: [ProduceSpec] = [],
                uses: [String] = [], present: String = "output") {
        self.name = name; self.summary = summary; self.usecases = usecases; self.args = args; self.produces = produces
        self.uses = uses; self.present = present
    }

    enum CodingKeys: String, CodingKey { case name, summary, usecases, args, produces, uses, present }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decode(String.self, forKey: .name)
        summary = try keyed.decodeIfPresent(String.self, forKey: .summary) ?? ""
        usecases = try keyed.decodeIfPresent([String].self, forKey: .usecases) ?? []
        args = try keyed.decodeIfPresent([ArgumentSpec].self, forKey: .args) ?? []
        produces = try keyed.decodeIfPresent([ProduceSpec].self, forKey: .produces) ?? []
        uses = try keyed.decodeIfPresent([String].self, forKey: .uses) ?? []
        present = try keyed.decodeIfPresent(String.self, forKey: .present) ?? "output"
    }
}
