import CraftedCore
import Foundation
import XCTest
@testable import CraftedForge

/// Where the engineer track's checked-in pieces are, from this file: the template, the fixtures, the scripts.
enum EngineerPaths {
    static let repository = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let templates = repository.appendingPathComponent("Templates", isDirectory: true)
    static let skeleton = templates.appendingPathComponent("EngineerAgentSkeleton", isDirectory: true)
    static let projects = repository.appendingPathComponent("Fixtures/projects", isDirectory: true)
    static let scripts = repository.appendingPathComponent("Fixtures/scripts", isDirectory: true)

    static func project(_ name: String) -> URL { projects.appendingPathComponent(name, isDirectory: true) }

    /// Fixtures/ is kept off the public repository (.gitignore): a test that reads a fixture project skips without it.
    static func requireFixtures() throws {
        guard FileManager.default.fileExists(atPath: projects.path) else {
            throw XCTSkip("Fixtures/projects is not in this checkout; it is kept off the public repository.")
        }
    }

    /// The template's sample port (the tip calculator).
    static func sampleSpec() throws -> PortSpec {
        try JSONDecoder().decode(PortSpec.self, from: Data(contentsOf: skeleton.appendingPathComponent("Sample/port.json")))
    }

    static func temporaryFolder(_ name: String = "engineer") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
