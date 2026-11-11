//  WHAT: The live toolchain: `swift build` and `swift test` with a scratch path, diagnostics parsed, and Granite's
//        AgentInstaller for the install gate (install, --describe, one perform over the wire).
//  OUT:  ForgeService and crafted-check give it to the Forge.
//  TODO(forge-gates track): the implementation. This stub reports no toolchain, so the forge skips the build gates.

import CraftedForge
import Foundation

public struct SwiftToolchain: ForgeToolchain {
    public init() {}

    public func version() async -> String? { nil }

    public func build(package: URL, target: String?, scratch: URL) async throws -> BuildResult {
        throw ForgeError.noToolchain("not wired yet")
    }

    public func test(package: URL, filter: String?, scratch: URL) async throws -> TestResult {
        throw ForgeError.noToolchain("not wired yet")
    }

    public func install(package: URL, shelf: URL) async throws -> InstalledAgent {
        throw ForgeError.noToolchain("not wired yet")
    }

    public func describe(_ agent: InstalledAgent) async throws -> Data {
        throw ForgeError.noToolchain("not wired yet")
    }

    public func perform(_ agent: InstalledAgent, word: String, input: Data, directory: URL) async throws -> CallOutcome {
        throw ForgeError.noToolchain("not wired yet")
    }
}
