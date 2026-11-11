//  WHAT: Runs a unit's vectors: each contract function called from JSON (Generated/VectorCalls.swift), its result held
//        to the vector's exact value, error or property. A failure names the vector, what was expected and what came.
//  IN:   Vectors/<Unit>.vectors.json beside this file.
//  OUT:  Generated/VectorTests.swift, a test per unit; the forge runs one unit's test as a rung of its port.
//  PIN:  A STUB IS SKIPPED, NOT PASSED. A unit whose body is not ported throws `notPorted`; its test is skipped, and a
//        package holding a stub is never offered (the agent's tests check for one).

import Foundation
import SkeletonCore
import XCTest

enum VectorHarness {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Vectors", isDirectory: true)

    static func check(unit: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let url = folder.appendingPathComponent("\(unit).vectors.json")
        guard let data = try? Data(contentsOf: url) else { throw VectorFailure.missingFile(url.path) }
        let vectors = try JSONDecoder().decode(VectorFile.self, from: data)
        XCTAssertFalse(vectors.vectors.isEmpty, "\(unit) has no vectors", file: file, line: line)
        for vector in vectors.vectors {
            do {
                if let problem = try verdict(unit: unit, vector) {
                    XCTFail("vector \"\(vector.name)\" (\(unit).\(vector.function)): \(problem)", file: file, line: line)
                }
            } catch let failure as CoreFailure {
                if case .notPorted = failure { throw XCTSkip("\(unit) is not ported yet") }
                XCTFail("vector \"\(vector.name)\" (\(unit).\(vector.function)): threw \(failure)", file: file, line: line)
            }
        }
    }

    /// Nil when the vector holds; else what went wrong.
    static func verdict(unit: String, _ vector: Vector) throws -> String? {
        let tolerance = vector.tolerance ?? 1e-9
        func call(_ args: [String: VectorJSON]) throws -> VectorJSON {
            try VectorCalls.call(unit, vector.function, VectorArguments(values: args))
        }
        if vector.expectError == true || vector.property?.kind == "throws" {
            do {
                let result = try call(vector.args)
                return "expected an error, got \(result)"
            } catch let failure as CoreFailure {
                if case .notPorted = failure { throw failure }
                return nil
            } catch {
                return nil
            }
        }
        let result: VectorJSON
        do {
            result = try call(vector.args)
        } catch let failure as CoreFailure {
            if case .notPorted = failure { throw failure }
            return "threw \(failure)"
        } catch {
            return "threw \(error)"
        }
        if let expect = vector.expect {
            return result.matches(expect, tolerance: tolerance) ? nil : "expected \(expect), got \(result)"
        }
        guard let property = vector.property else { return "the vector says nothing to check" }
        return try VectorProperties.verdict(property, result: result, args: vector.args, tolerance: tolerance) { function, args in
            try VectorCalls.call(unit, function ?? vector.function, VectorArguments(values: args))
        }
    }
}
