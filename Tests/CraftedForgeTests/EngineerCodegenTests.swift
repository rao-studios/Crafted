import CraftedCore
import Foundation
import XCTest
@testable import CraftedForge

/// The template's sample port is held to the codegen: every file code writes for the tip calculator's spec is in the
/// template byte for byte, and every generated folder holds nothing else. `CRAFTED_WRITE_SAMPLE=1` writes them.
final class EngineerCodegenTests: XCTestCase {
    func testTheSamplesGeneratedFilesAreWhatTheCodegenWrites() throws {
        let spec = try EngineerPaths.sampleSpec()
        let ported: Set<String> = ["TipMath", SkeletonCodegen.handlerKey("tip"), SkeletonCodegen.handlerKey("split")]
        let files = SkeletonCodegen.files(spec, ported: ported)
        if ProcessInfo.processInfo.environment["CRAFTED_WRITE_SAMPLE"] == "1" {
            for (path, text) in files {
                let url = EngineerPaths.skeleton.appendingPathComponent(path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(text.utf8).write(to: url)
            }
        }
        for (path, text) in files.sorted(by: { $0.key < $1.key }) {
            let held = try? String(contentsOf: EngineerPaths.skeleton.appendingPathComponent(path), encoding: .utf8)
            XCTAssertEqual(held, text, "\(path) drifted from the codegen: run with CRAFTED_WRITE_SAMPLE=1 and review")
        }
        for folder in ["Sources/SkeletonAgent/Surface", "Sources/SkeletonCore/Contracts", "Sources/SkeletonCore/Domain",
                       "Tests/SkeletonCoreTests/Generated", "Tests/SkeletonAgentTests/Generated"] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: EngineerPaths.skeleton.appendingPathComponent(folder).path)) ?? []
            for name in names where !name.hasPrefix(".") {
                XCTAssertNotNil(files[folder + "/" + name], "\(folder)/\(name) is in the template but the codegen does not write it")
            }
        }
    }

    func testAStubIsWrittenForEveryUnportedUnitAndHandler() throws {
        let spec = try EngineerPaths.sampleSpec()
        let files = SkeletonCodegen.files(spec)
        let logic = try XCTUnwrap(files[SkeletonLayout.logic("TipMath")])
        XCTAssertTrue(SkeletonCodegen.isStub(logic))
        XCTAssertTrue(logic.contains("public static func percent(for service: String) throws -> Double"))
        XCTAssertTrue(logic.contains("CoreFailure.notPorted(\"TipMath.percent\")"))
        XCTAssertTrue(SkeletonCodegen.isStub(try XCTUnwrap(files[SkeletonLayout.handler("split")])))
    }

    func testTheInputIsFlatAndAllOptionalWithTheSharedFieldsLast() throws {
        let spec = try EngineerPaths.sampleSpec()
        let input = SurfaceCodegen.input(spec)
        let fields = input.split(separator: "\n").filter { $0.hasPrefix("    public var ") }.map { $0.split(separator: " ")[2].dropLast() }
        XCTAssertEqual(fields.map(String.init), ["command", "bill", "percent", "service", "people", "brief", "handoff", "present", "output", "seed", "directory"])
        XCTAssertTrue(input.contains("public var service: ServiceChoice?"))
    }

    func testDroppingACommandDropsWhatOnlyItUsed() throws {
        var spec = try EngineerPaths.sampleSpec()
        spec.units.append(UnitContract(unit: "Rounding", functions: [FunctionSpec(name: "cents", params: [ParameterSpec(name: "amount", type: "Double")], returns: "Double")]))
        spec.commands[1].uses.append("Rounding")
        let dropped = spec.dropping(["split"])
        XCTAssertEqual(dropped.commands.map(\.name), ["tip"])
        XCTAssertEqual(dropped.units.map(\.unit), ["TipMath"])
        XCTAssertEqual(dropped.types.map(\.name), ["TipBreakdown"])
    }
}
