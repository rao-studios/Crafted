//  WHAT: One logic unit's contract: the functions the port must write, each with labelled parameters, a return type
//        and the rules it keeps, the domain types it names, the carried resources it reads, the other units it calls,
//        and the source lines it is ported from.
//  OUT:  Codegen (a protocol per unit, a stub, the vector runner's calls), the port loop's prompts.
//  PIN:  TYPES THE VECTOR RUNNER CAN MAKE FROM JSON. Int Double Bool String Date Data Decimal, arrays, String-keyed
//        dictionaries, optionals and declared domain types: no generics, closures or tuples (SwiftTypeName checks).

import Foundation

public struct UnitContract: Codable, Sendable, Equatable {
    public var unit: String
    /// `logic` (pure functions), `lifted` (calls a lifted file).
    public var kind: String
    /// Domain types it names.
    public var uses: [String]
    /// Carried resources it reads by name (CoreResources).
    public var resources: [String]
    /// Other units it calls.
    public var calls: [String]
    public var functions: [FunctionSpec]
    /// "path:12-30", the lines it ports.
    public var evidence: [String]
    /// What it is, in a sentence.
    public var summary: String

    public init(unit: String, kind: String = "logic", uses: [String] = [], resources: [String] = [], calls: [String] = [],
                functions: [FunctionSpec], evidence: [String] = [], summary: String = "") {
        self.unit = unit; self.kind = kind; self.uses = uses; self.resources = resources; self.calls = calls
        self.functions = functions; self.evidence = evidence; self.summary = summary
    }

    enum CodingKeys: String, CodingKey { case unit, kind, uses, resources, calls, functions, evidence, summary }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        unit = try keyed.decode(String.self, forKey: .unit)
        kind = try keyed.decodeIfPresent(String.self, forKey: .kind) ?? "logic"
        uses = try keyed.decodeIfPresent([String].self, forKey: .uses) ?? []
        resources = try keyed.decodeIfPresent([String].self, forKey: .resources) ?? []
        calls = try keyed.decodeIfPresent([String].self, forKey: .calls) ?? []
        functions = try keyed.decode([FunctionSpec].self, forKey: .functions)
        evidence = try keyed.decodeIfPresent([String].self, forKey: .evidence) ?? []
        summary = try keyed.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }

    /// Every declared type its functions name.
    public var namedTypes: Swift.Set<String> {
        var names = Swift.Set(uses)
        for function in functions {
            names.formUnion(SwiftTypeName.named(in: function.returns))
            for parameter in function.params { names.formUnion(SwiftTypeName.named(in: parameter.type)) }
        }
        return names
    }

    /// The protocol a unit conforms to.
    public var contractName: String { unit + "Contract" }
}
