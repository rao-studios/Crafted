import Foundation

/// A line that touches the world, as code found it: its kind, line and text.
public struct EffectLine: Codable, Sendable, Equatable {
    /// file, network, process, output, ui, clock, random, env, entry
    public var kind: String
    public var line: Int
    public var detail: String
}
