import Foundation

/// What the port loop writes: a logic unit, or a command's handler.
public enum PortTaskKind: String, Codable, Sendable {
    case unit
    case handler
}
