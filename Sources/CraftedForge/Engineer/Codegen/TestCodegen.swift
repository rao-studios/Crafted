//  WHAT: The test side of a port, written from the plan: the vector runner's calls (each contract function called from
//        a vector's JSON arguments), a test per unit and per command, and the schema the conformance test expects.
//  OUT:  SkeletonCodegen.

import Foundation

enum TestCodegen {
    static func vectorCalls(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\nimport SkeletonCore\n\n"
        text += "/// Every contract function, called by its unit's and its own name with arguments made from a vector's JSON.\n"
        text += "enum VectorCalls {\n"
        text += "    static func call(_ unit: String, _ function: String, _ arguments: VectorArguments) throws -> VectorJSON {\n"
        text += "        switch unit + \".\" + function {\n"
        for unit in spec.units {
            for function in unit.functions {
                let arguments = function.params.map { "\($0.callLabel)arguments.value(\(SwiftText.literal($0.name)))" }.joined(separator: ", ")
                text += "        case \(SwiftText.literal("\(unit.unit).\(function.name)")):\n"
                text += "            return try VectorJSON.encoding(\(unit.unit).\(function.name)(\(arguments)))\n"
            }
        }
        text += "        default:\n"
        text += "            throw VectorFailure.unknownFunction(unit + \".\" + function)\n"
        text += "        }\n    }\n}\n"
        return text
    }

    static func vectorTests(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport XCTest\n\n"
        text += "/// A test per unit: every vector in Vectors/<Unit>.vectors.json.\n"
        text += "final class VectorTests: XCTestCase {\n"
        for (index, unit) in spec.units.enumerated() {
            if index > 0 { text += "\n" }
            text += "    func test\(unit.unit)() throws {\n"
            text += "        try VectorHarness.check(unit: \(SwiftText.literal(unit.unit)))\n"
            text += "    }\n"
        }
        return text + "}\n"
    }

    static func callTests(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport XCTest\n\n"
        text += "/// A test per command: its canonical call (Calls/<command>.call.json) answers a conforming answer.\n"
        text += "final class CallTests: XCTestCase {\n"
        for (index, command) in spec.commands.enumerated() {
            if index > 0 { text += "\n" }
            text += "    func test\(SwiftText.pascal(command.name))Call() async throws {\n"
            text += "        try await CallHarness.check(command: \(SwiftText.literal(command.name)))\n"
            text += "    }\n"
        }
        return text + "}\n"
    }

    static func expectedSurface(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport GraniteAgents\n\n"
        text += "/// The input schema a host reads off the agent, as the plan says it should be.\n"
        text += "enum ExpectedSurface {\n"
        text += "    static let commands = [" + spec.commands.map { SwiftText.literal($0.name) }.joined(separator: ", ") + "]\n\n"
        text += "    static let schema = GraniteSchema.object([\n"
        text += "        .init(name: \"command\", schema: .choice(commands), required: false),\n"
        for field in spec.fields {
            text += "        .init(name: \(SwiftText.literal(field.name)), schema: \(schema(field)), required: false),\n"
        }
        text += "        .init(name: \"brief\", schema: .string, required: false),\n"
        text += "        .init(name: \"handoff\", schema: .string, required: false),\n"
        text += "        .init(name: \"present\", schema: .choice([\"output\", \"canvas\", \"context\"]), required: false),\n"
        text += "        .init(name: \"output\", schema: .string, required: false),\n"
        text += "        .init(name: \"seed\", schema: .integer, required: false),\n"
        text += "        .init(name: \"directory\", schema: .string, required: false),\n"
        text += "    ])\n}\n"
        return text
    }

    static func schema(_ field: ArgumentSpec) -> String {
        switch field.type {
        case "integer": return ".integer"
        case "number": return ".number"
        case "boolean": return ".boolean"
        case "choice": return ".choice([" + (field.values ?? []).map(SwiftText.literal).joined(separator: ", ") + "])"
        case "[string]": return ".array(.string)"
        case "[number]": return ".array(.number)"
        default: return ".string"
        }
    }
}
