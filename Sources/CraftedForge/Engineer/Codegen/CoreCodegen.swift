//  WHAT: The logic's frame, written from the unit contracts: a protocol per unit (what the port must write, checked by
//        the compiler), the domain types the contracts name (Codable records and string choices), and a stub per unit
//        and handler until its port lands.
//  OUT:  SkeletonCodegen.
//  PIN:  EVERY CONTRACT FUNCTION THROWS. A port may write one that does not; the vector runner and the handlers call
//        each with `try`, and a stub throws `notPorted` instead of crashing a test.

import Foundation

enum CoreCodegen {
    static func contract(_ unit: UnitContract) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\n\n"
        text += SwiftText.doc("\(unit.unit)'s contract: what its port must write. " + unit.summary)
        text += "public protocol \(unit.contractName) {\n"
        for (index, function) in unit.functions.enumerated() {
            if index > 0 { text += "\n" }
            if !function.rules.isEmpty { text += SwiftText.doc(function.rules.joined(separator: " "), indent: "    ") }
            text += "    static func \(function.signature)\n"
        }
        return text + "}\n"
    }

    static func domain(_ type: DomainType) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\n\n"
        if !type.note.isEmpty { text += SwiftText.doc(type.note) }
        if type.kind == "enum" {
            text += "public enum \(type.name): String, Codable, Sendable, Equatable, CaseIterable {\n"
            for value in type.cases {
                text += SwiftText.isPlainCase(value) ? "    case \(value)\n" : "    case \(SwiftText.caseName(value)) = \(SwiftText.literal(value))\n"
            }
            return text + "}\n"
        }
        text += "public struct \(type.name): Codable, Sendable, Equatable {\n"
        for field in type.fields {
            if !field.note.isEmpty { text += SwiftText.doc(field.note, indent: "    ") }
            text += "    public var \(field.name): \(field.type)\n"
        }
        text += "\n    public init(" + type.fields.map { "\($0.name): \($0.type)" }.joined(separator: ", ") + ") {\n"
        for field in type.fields { text += "        self.\(field.name) = \(field.name)\n" }
        return text + "    }\n}\n"
    }

    static func logicStub(_ unit: UnitContract) -> String {
        var text = SwiftText.stubMarker + ": \(unit.unit) is not ported yet. A package that still holds this line is never offered.\n\n"
        text += "import Foundation\n\n"
        text += "public enum \(unit.unit): \(unit.contractName) {\n"
        for function in unit.functions {
            text += "    public static func \(function.signature) {\n"
            text += "        throw CoreFailure.notPorted(\(SwiftText.literal("\(unit.unit).\(function.name)")))\n"
            text += "    }\n"
        }
        return text + "}\n"
    }

    static func handlerStub(_ command: CommandSpec) -> String {
        let name = SwiftText.pascal(command.name)
        var text = SwiftText.stubMarker + ": `\(command.name)` is not ported yet. A package that still holds this line is never offered.\n\n"
        text += "import Foundation\nimport GraniteAgents\n\n"
        text += "enum \(name)Handler: CommandHandler {\n"
        text += "    static func run(_ arguments: \(name)Arguments, _ kit: CommandKit) async throws -> [Product] {\n"
        text += "        throw AgentRefusal(.host, \(SwiftText.literal("`\(command.name)` is not ported yet.")))\n"
        text += "    }\n}\n"
        return text
    }
}
