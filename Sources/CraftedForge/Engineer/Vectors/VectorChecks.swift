//  WHAT: A unit's vectors held to its contract and the source: every function is the unit's, every argument a
//        parameter and every parameter given; each vector says one thing to check; a property is one the runner knows;
//        a source-test vector cites a test file of the project; an exact derived value its own arithmetic gives.
//  OUT:  VectorStage (the structured ask's check); tests.

import CraftedCore
import Foundation

public enum VectorChecks {
    public static let properties: Swift.Set<String> = [
        "equals", "approx", "roundTrip", "monotonic", "sumsTo", "inRange", "deterministic", "throws", "permutationOf", "lengthIs", "matches",
    ]

    public static func problems(_ vectors: [VectorSpec], unit: UnitContract, inventory: Inventory) -> [String] {
        var problems: [String] = []
        if vectors.count < 2 { problems.append("\(unit.unit) needs two vectors or more") }
        let functions = Dictionary(unit.functions.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var covered: Swift.Set<String> = []
        for vector in vectors {
            guard let function = functions[vector.function] else {
                problems.append("vector \"\(vector.name)\" calls \(vector.function), which is not a function of \(unit.unit)"); continue
            }
            covered.insert(function.name)
            let names = Swift.Set(function.params.map(\.name))
            for key in vector.args.keys where !names.contains(key) {
                problems.append("vector \"\(vector.name)\" gives \(key), which \(function.name) does not take")
            }
            for parameter in function.params where vector.args[parameter.name] == nil && !parameter.type.hasSuffix("?") {
                problems.append("vector \"\(vector.name)\" leaves out \(parameter.name), which \(function.name) needs")
            }
            let says = [vector.expect != nil, vector.expectError == true, vector.property != nil].filter { $0 }.count
            if says != 1 { problems.append("vector \"\(vector.name)\" must say exactly one of expect, expectError or property") }
            if let property = vector.property {
                let kind = property["kind"]?.stringValue ?? ""
                if !properties.contains(kind) { problems.append("vector \"\(vector.name)\" has a property \(kind): use " + properties.sorted().joined(separator: ", ")) }
            }
            if vector.origin == "source-test" {
                let cited = vector.evidence.flatMap(Evidence.parse)
                if cited.flatMap({ inventory.file($0.path) })?.verdict != .test {
                    problems.append("vector \"\(vector.name)\" is from a source test but cites \(vector.evidence ?? "nothing"), which is not a test file of the project")
                }
            } else if vector.origin != "derived" {
                problems.append("vector \"\(vector.name)\" has origin \(vector.origin): use source-test or derived")
            }
            if let arithmetic = vector.arithmetic, let expect = vector.expect?.doubleValue {
                guard let value = Arithmetic.evaluate(arithmetic) else {
                    problems.append("vector \"\(vector.name)\": \(arithmetic) is not plain arithmetic"); continue
                }
                let tolerance = max(vector.tolerance ?? 1e-9, 1e-9 * max(abs(value), 1))
                if abs(value - expect) > tolerance {
                    problems.append("vector \"\(vector.name)\" expects \(expect), but its arithmetic \(arithmetic) gives \(value)")
                }
            }
        }
        for function in unit.functions where !covered.contains(function.name) {
            problems.append("no vector calls \(unit.unit).\(function.name)")
        }
        return problems
    }

    /// Every third vector held out of the port's prompt, the rest shown.
    public static func holdingOut(_ vectors: [VectorSpec]) -> [VectorSpec] {
        vectors.enumerated().map { index, vector in
            var vector = vector
            vector.held = index % 3 == 2
            return vector
        }
    }
}
