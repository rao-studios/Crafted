import Foundation

/// A command as a refusal or a guide lists it: its name, its arguments' names, and what it does.
public struct CommandEntry: Sendable, Equatable {
    public var name: String
    public var arguments: [String]
    public var summary: String

    public init(name: String, arguments: [String], summary: String) {
        self.name = name; self.arguments = arguments; self.summary = summary
    }
}
