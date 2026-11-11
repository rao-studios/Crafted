import CraftedCore
import Foundation

/// A command's canonical call, as the coder writes it and the package's call harness reads it
/// (Tests/<Agent>Tests/Calls/<command>.call.json): the input a host sends with no model, files the call reads, and
/// the facts its answer must carry.
public struct CallSpec: Codable, Sendable, Equatable {
    public var command: String
    public var input: [String: JSONValue]
    public var files: [String: String]?
    public var expect: JSONValue?

    public init(command: String, input: [String: JSONValue], files: [String: String]? = nil, expect: JSONValue? = nil) {
        self.command = command; self.input = input; self.files = files; self.expect = expect
    }

    /// Why the call cannot be `command`'s canonical call, one sentence each.
    public func problems(for command: CommandSpec) -> [String] {
        var problems: [String] = []
        if self.command != command.name { problems.append("the call is for \(self.command), not \(command.name)") }
        if input["command"]?.stringValue != command.name { problems.append("input.command must be \"\(command.name)\"") }
        let takes = Swift.Set(command.args.map(\.name)).union(["command", "present", "output", "seed", "handoff"])
        for key in input.keys where !takes.contains(key) { problems.append("input gives \(key), which \(command.name) does not take") }
        if input["directory"] != nil { problems.append("input gives directory, which is the host's") }
        for argument in command.args where argument.required && input[argument.name] == nil {
            problems.append("input leaves out \(argument.name), which \(command.name) needs")
        }
        for argument in command.args where argument.type == "choice" {
            if let value = input[argument.name]?.stringValue, !(argument.values ?? []).contains(value) {
                problems.append("\(argument.name) is \(value), not one of " + (argument.values ?? []).joined(separator: ", "))
            }
        }
        for path in (files ?? [:]).keys where path.hasPrefix("/") || path.contains("..") {
            problems.append("file \(path) must be relative to the project")
        }
        return problems
    }
}
