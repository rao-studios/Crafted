//  WHAT: The port's plan, as code reads it: what the agent says it is (summary, guide), its commands (commands.json),
//        the logic units each command uses with their contracts, the domain types the contracts name, and the files
//        carried or lifted from the source as they are.
//  IN:   The plan stage (the coder's `engineer.plan` answer, checked by PlanChecks); the template's Sample/port.json.
//  OUT:  Codegen (the surface, contracts, types, stubs and test runners), the port loop, assembly.
//  PIN:  ONE SPEC, ONE PACKAGE. Every generated file is a function of this value; dropping a command is a new spec
//        (`dropping(_:)`) and a new assembly, never an edit.

import Foundation

public struct PortSpec: Codable, Sendable, Equatable {
    /// One sentence: what the agent does (the package's `summary`).
    public var summary: String
    /// How to use it well (the package's `guide`); a line per command is added by code.
    public var guide: String
    public var commands: [CommandSpec]
    public var units: [UnitContract]
    public var types: [DomainType]
    /// Source files carried into Resources/ as they are: tables, templates, samples.
    public var resources: [CarriedFile]
    /// Swift source files lifted into Lifted/ as they are, with a provenance header.
    public var lifts: [CarriedFile]

    public init(summary: String, guide: String, commands: [CommandSpec], units: [UnitContract] = [], types: [DomainType] = [],
                resources: [CarriedFile] = [], lifts: [CarriedFile] = []) {
        self.summary = summary; self.guide = guide; self.commands = commands; self.units = units; self.types = types
        self.resources = resources; self.lifts = lifts
    }

    enum CodingKeys: String, CodingKey { case summary, guide, commands, units, types, resources, lifts }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        summary = try keyed.decode(String.self, forKey: .summary)
        guide = try keyed.decodeIfPresent(String.self, forKey: .guide) ?? ""
        commands = try keyed.decode([CommandSpec].self, forKey: .commands)
        units = try keyed.decodeIfPresent([UnitContract].self, forKey: .units) ?? []
        types = try keyed.decodeIfPresent([DomainType].self, forKey: .types) ?? []
        resources = try keyed.decodeIfPresent([CarriedFile].self, forKey: .resources) ?? []
        lifts = try keyed.decodeIfPresent([CarriedFile].self, forKey: .lifts) ?? []
    }

    /// The unit called `name`.
    public func unit(_ name: String) -> UnitContract? { units.first { $0.unit == name } }

    /// Every field of the generated input that a command takes, in first-seen order, with the spec that first named it.
    public var fields: [ArgumentSpec] {
        var seen: [String: Int] = [:]
        var fields: [ArgumentSpec] = []
        for command in commands {
            for argument in command.args {
                if let index = seen[argument.name] {
                    // A choice named by two commands takes the values of both.
                    if argument.type == "choice", let values = argument.values {
                        let merged = (fields[index].values ?? []) + values.filter { !(fields[index].values ?? []).contains($0) }
                        fields[index].values = merged
                    }
                    continue
                }
                seen[argument.name] = fields.count
                fields.append(argument)
            }
        }
        return fields
    }

    /// This spec without `commands`, and without every unit and type only they used.
    public func dropping(_ dropped: Swift.Set<String>) -> PortSpec {
        var spec = self
        spec.commands = commands.filter { !dropped.contains($0.name) }
        let used = Swift.Set(spec.commands.flatMap(\.uses))
        var keep = used
        // Units used by kept units stay too.
        var grew = true
        while grew {
            grew = false
            for unit in units where keep.contains(unit.unit) {
                for name in unit.calls where !keep.contains(name) && units.contains(where: { $0.unit == name }) {
                    keep.insert(name); grew = true
                }
            }
        }
        spec.units = units.filter { keep.contains($0.unit) }
        let typeNames = Swift.Set(spec.units.flatMap(\.namedTypes))
        var keptTypes = typeNames
        for type in types where keptTypes.contains(type.name) {
            for field in type.fields { keptTypes.formUnion(SwiftTypeName.named(in: field.type)) }
        }
        spec.types = types.filter { keptTypes.contains($0.name) }
        return spec
    }
}
