import Foundation
import GraniteAgents

/// A hand-off file named by a call's `handoff` field, read and held to its format and size.
enum HandoffReader {
    static func read(_ url: URL) throws -> Handoff {
        guard let data = try? Data(contentsOf: url) else {
            throw AgentRefusal(.call, "The hand-off \(url.lastPathComponent) could not be read: give the path an upstream agent named in its answer.")
        }
        guard data.count <= Handoff.limit else {
            throw AgentRefusal(.call, "The hand-off \(url.lastPathComponent) is over 64 KB: hand on a smaller one.")
        }
        guard let handoff = try? JSONDecoder().decode(Handoff.self, from: data), handoff.format == Handoff.format else {
            throw AgentRefusal(.call, "\(url.lastPathComponent) is not a \(Handoff.format) file: give a .handoff.json an agent wrote.")
        }
        return handoff
    }
}
