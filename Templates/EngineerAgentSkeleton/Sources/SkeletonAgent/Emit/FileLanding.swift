//  WHAT: A call's files written together or not at all: each staged in a folder of its own, then moved into place.
//  PIN:  WHOLE OR NOTHING. A file that cannot be staged ends the call before anything lands in the project.
//  PIN:  NEVER PRINT. Stdout is the wire's.

import Foundation
import GraniteAgents

enum FileLanding {
    static func land(_ files: [PlannedFile], under directory: URL) throws -> [LandedFile] {
        guard !files.isEmpty else { return [] }
        let manager = FileManager.default
        let stage = manager.temporaryDirectory.appendingPathComponent("agent-stage-\(UUID().uuidString.prefix(8))", isDirectory: true)
        defer { try? manager.removeItem(at: stage) }
        try manager.createDirectory(at: stage, withIntermediateDirectories: true)
        var staged: [(URL, PlannedFile)] = []
        for (index, file) in files.enumerated() {
            let place = stage.appendingPathComponent("\(index)")
            do {
                try file.data.write(to: place)
            } catch {
                throw AgentRefusal(.host, "\(file.path) could not be staged (\(error)): free some space and try again.")
            }
            staged.append((place, file))
        }
        return try staged.map { place, file in
            let target = directory.appendingPathComponent(file.path)
            let existed = manager.fileExists(atPath: target.path)
            do {
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if existed { try manager.removeItem(at: target) }
                try manager.moveItem(at: place, to: target)
            } catch {
                throw AgentRefusal(.call, "\(file.path) could not be written (\(error)): give an `output` folder the agent may write to.")
            }
            return LandedFile(planned: file, path: target.path, existed: existed)
        }
    }
}
