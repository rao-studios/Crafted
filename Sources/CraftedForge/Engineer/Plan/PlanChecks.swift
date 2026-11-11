//  WHAT: A port plan held to what code can generate and the store will take: at most 6 commands, 6 arguments each and
//        16 distinct fields; names that are Swift identifiers and clash with nothing the template declares; one type
//        per field name; contract types the vector runner can make from JSON; units, types and carried files that
//        exist; every command resting on a verified use case.
//  OUT:  PlanStage (the structured ask's check); tests.

import Foundation

public enum PlanChecks {
    /// Names the template declares, which a port may not reuse.
    public static let reservedTypes: Swift.Set<String> = [
        "CoreResources", "CoreFailure", "SeededGenerator", "Command", "AgentInput", "Dispatch", "Surface", "Router", "Interpreter",
        "CommandKit", "CommandHandler", "CommandEntry", "Product", "Report", "ReportBlock", "ReportBar", "Fact", "FactValue",
        "AgentResult", "AgentFrame", "Presentation", "Handoff", "HandoffSource", "HandoffTable", "HandoffText", "HandoffFile",
        "TimeSeries", "TimeSeriesLine", "TimeSeriesPoint", "TimeSeriesMark", "Refusals", "Emitter", "VectorCalls", "VectorJSON",
        "String", "Int", "Double", "Bool", "Date", "Data", "Decimal", "Array", "Dictionary", "Set", "Optional", "Error",
    ]
    /// Fields every command shares.
    public static let sharedFields: Swift.Set<String> = ["command", "brief", "handoff", "present", "output", "seed", "directory"]

    public static func problems(_ spec: PortSpec, verified: Swift.Set<String>, inventory: Inventory) -> [String] {
        var problems: [String] = []
        if spec.summary.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("summary is empty") }
        if spec.commands.isEmpty || spec.commands.count > 6 { problems.append("the plan has \(spec.commands.count) commands: give 1 to 6") }
        let units = Swift.Set(spec.units.map(\.unit))
        let types = Swift.Set(spec.types.map(\.name))
        var fieldTypes: [String: String] = [:]
        var commandNames: Swift.Set<String> = []
        for command in spec.commands {
            if !isLowerName(command.name) { problems.append("command \(command.name) is not a lowerCamelCase Swift name") }
            if !commandNames.insert(command.name).inserted { problems.append("two commands are called \(command.name)") }
            if command.args.count > 6 { problems.append("\(command.name) has \(command.args.count) arguments; six at most") }
            if !command.usecases.contains(where: verified.contains) {
                problems.append("\(command.name) rests on no verified use case (\(verified.sorted().joined(separator: ", ")))")
            }
            if !["output", "canvas", "context"].contains(command.present) { problems.append("\(command.name) presents as \(command.present): use output, canvas or context") }
            for produce in command.produces where !ProduceSpec.kinds.contains(produce.kind) {
                problems.append("\(command.name) produces a \(produce.kind): use " + ProduceSpec.kinds.sorted().joined(separator: ", "))
            }
            for unit in command.uses where !units.contains(unit) { problems.append("\(command.name) uses \(unit), which is not a unit of the plan") }
            var argumentNames: Swift.Set<String> = []
            for argument in command.args {
                if !argumentNames.insert(argument.name).inserted { problems.append("\(command.name) takes \(argument.name) twice") }
                if !isLowerName(argument.name) || sharedFields.contains(argument.name) {
                    problems.append("argument \(argument.name) of \(command.name) must be a lowerCamelCase name and not one of " + sharedFields.sorted().joined(separator: ", "))
                }
                if !ArgumentSpec.types.contains(argument.type) {
                    problems.append("argument \(argument.name) of \(command.name) is a \(argument.type): use " + ArgumentSpec.types.sorted().joined(separator: ", "))
                }
                if argument.type == "choice", (argument.values ?? []).isEmpty { problems.append("argument \(argument.name) of \(command.name) is a choice with no values") }
                if let earlier = fieldTypes[argument.name], earlier != argument.type {
                    problems.append("\(argument.name) is a \(earlier) in one command and a \(argument.type) in \(command.name): one name, one type")
                }
                fieldTypes[argument.name] = argument.type
            }
        }
        if fieldTypes.count > 16 { problems.append("the commands take \(fieldTypes.count) distinct arguments; sixteen at most") }
        var unitNames: Swift.Set<String> = []
        for unit in spec.units {
            if !isTypeName(unit.unit) { problems.append("unit \(unit.unit) must be an UpperCamelCase Swift name the template does not use") }
            if !unitNames.insert(unit.unit).inserted { problems.append("two units are called \(unit.unit)") }
            if unit.functions.isEmpty { problems.append("unit \(unit.unit) has no functions") }
            var functionNames: Swift.Set<String> = []
            for function in unit.functions {
                if !isLowerName(function.name) { problems.append("\(unit.unit).\(function.name) is not a lowerCamelCase Swift name") }
                if !functionNames.insert(function.name).inserted { problems.append("\(unit.unit) has two functions called \(function.name): name each once") }
                if let why = SwiftTypeName.problem(function.returns, declared: types) { problems.append("\(unit.unit).\(function.name) returns \(why)") }
                for parameter in function.params {
                    if !SwiftTypeName.isIdentifier(parameter.name) || SwiftText.keywords.contains(parameter.name) {
                        problems.append("\(unit.unit).\(function.name) has a parameter named \(parameter.name)")
                    }
                    if let why = SwiftTypeName.problem(parameter.type, declared: types) { problems.append("\(unit.unit).\(function.name)(\(parameter.name)): \(why)") }
                }
            }
            for other in unit.calls where !units.contains(other) { problems.append("\(unit.unit) calls \(other), which is not a unit of the plan") }
            if unit.evidence.isEmpty { problems.append("unit \(unit.unit) cites no evidence") }
            for citation in unit.evidence {
                guard let evidence = Evidence.parse(citation), inventory.file(evidence.path)?.verdict.isOpened == true else {
                    problems.append("unit \(unit.unit) cites \(citation), which is not a file of the project that was read"); continue
                }
            }
        }
        if let cycle = cycle(in: spec.units) { problems.append("units call each other in a circle: \(cycle)") }
        for type in spec.types {
            if !isTypeName(type.name) || units.contains(type.name) { problems.append("type \(type.name) must be an UpperCamelCase name no unit or template type uses") }
            if type.kind == "enum" {
                if type.cases.isEmpty { problems.append("enum \(type.name) has no cases") }
                for value in type.cases where !isLowerName(value) { problems.append("enum \(type.name) has a case \(value) that is not a lowerCamelCase name") }
            } else {
                if type.fields.isEmpty { problems.append("struct \(type.name) has no fields") }
                for field in type.fields {
                    if !isLowerName(field.name) { problems.append("\(type.name).\(field.name) is not a lowerCamelCase name") }
                    if let why = SwiftTypeName.problem(field.type, declared: types) { problems.append("\(type.name).\(field.name): \(why)") }
                }
            }
        }
        var carried: Swift.Set<String> = []
        for resource in spec.resources {
            if inventory.text(resource.source) == nil { problems.append("resource \(resource.source) is not a text file of the project that was read") }
            if !isFileName(resource.name) || !carried.insert(resource.name).inserted || resource.name == "RESOURCES.md" {
                problems.append("resource name \(resource.name) must be a plain, unique file name")
            }
        }
        for lift in spec.lifts {
            if !lift.source.hasSuffix(".swift") || inventory.text(lift.source) == nil { problems.append("lift \(lift.source) is not a Swift file of the project that was read") }
            if !lift.name.hasSuffix(".swift") || !isFileName(lift.name) { problems.append("lifted name \(lift.name) must be a plain .swift file name") }
        }
        return problems
    }

    static func isLowerName(_ name: String) -> Bool {
        SwiftTypeName.isIdentifier(name) && name.first?.isLowercase == true && !SwiftText.keywords.contains(name)
    }

    static func isTypeName(_ name: String) -> Bool {
        SwiftTypeName.isIdentifier(name) && name.first?.isUppercase == true && !reservedTypes.contains(name)
            && !["Contract", "Arguments", "Handler", "Choice"].contains(where: name.hasSuffix)
    }

    static func isFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }
    }

    /// A circle of units calling each other, said as "A → B → A", or nil.
    static func cycle(in units: [UnitContract]) -> String? {
        let calls = Dictionary(units.map { ($0.unit, $0.calls) }, uniquingKeysWith: { first, _ in first })
        func walk(_ unit: String, _ path: [String]) -> [String]? {
            if let at = path.firstIndex(of: unit) { return Array(path[at...]) + [unit] }
            for next in calls[unit] ?? [] { if let found = walk(next, path + [unit]) { return found } }
            return nil
        }
        for unit in units.map(\.unit) { if let found = walk(unit, []) { return found.joined(separator: " → ") } }
        return nil
    }

    /// Units in the order they are ported: a unit after the units it calls.
    public static func order(_ units: [UnitContract]) -> [UnitContract] {
        var placed: [UnitContract] = []
        var seen: Swift.Set<String> = []
        let byName = Dictionary(units.map { ($0.unit, $0) }, uniquingKeysWith: { first, _ in first })
        func visit(_ unit: UnitContract) {
            guard seen.insert(unit.unit).inserted else { return }
            for name in unit.calls { if let next = byName[name] { visit(next) } }
            placed.append(unit)
        }
        for unit in units { visit(unit) }
        return placed
    }
}
