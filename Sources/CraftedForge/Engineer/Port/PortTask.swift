//  WHAT: One thing the port loop writes, a logic unit or a command's handler, with everything its prompts show (the
//        contract, the source, the visible vectors, the hazard sheet) and where it is checked (the target it builds in,
//        the test that holds it).
//  OUT:  PortLoop.

import Foundation

struct PortTask: Sendable {
    var kind: PortTaskKind
    /// The unit's name, or the command's.
    var name: String
    /// The type the file declares: the unit, or `<Command>Handler`.
    var declares: String
    /// Where the file lives, by the template's names.
    var templatePath: String
    var functions: [FunctionSpec]
    /// The contract, as the prompt says it.
    var contract: String
    /// The source it ports, numbered.
    var source: String
    /// More of the source, for the re-read strategy.
    var widerSource: String
    /// The vectors or the canonical call it is held to, without the held-out ones.
    var shown: [String]
    var hazards: String?
    var brief: String
    /// The build target and test filter, by the template's names (stamped when run).
    var target: String
    var filter: String

    /// The prompt for `strategy`, after `last` failed with `body`; `function` for a split; `round` > 1 when the person
    /// asked to keep trying.
    func prompt(_ strategy: PortStrategy, last: AttemptFailure?, body: String?, function: FunctionSpec? = nil, round: Int) throws -> ModelPrompt {
        var user = brief + "\n\n"
        user += kind == .unit ? "The unit: \(name)\n" : "The command: \(name)\n"
        user += strategy.instruction + "\n\n"
        if round > 1 { user += "This is round \(round): the person asked to keep trying after every strategy failed.\n\n" }
        user += "Contract:\n" + contract + "\n\n"
        if let function { user += "The one function to write now: static func \(function.signature)\n" + function.rules.map { "  rule: \($0)" }.joined(separator: "\n") + "\n\n" }
        user += "Source:\n" + (strategy == .reread ? widerSource : source) + "\n\n"
        if !shown.isEmpty { user += (kind == .unit ? "Vectors it must pass (more are held back):\n" : "The canonical call it must answer:\n") + shown.map { "- " + $0 }.joined(separator: "\n") + "\n\n" }
        if let hazards { user += hazards + "\n\n" }
        if strategy == .repair, let body, let last {
            user += "Your last file:\n```swift\n\(body)```\n\n" + last.said + "\n"
        } else if let last {
            user += "The last try " + last.said.prefix(1).lowercased() + last.said.dropFirst() + "\n"
        }
        return try EngineerPrompts.prompt(kind == .unit ? .unit : .handler, user: user)
    }

    /// A unit file from functions written one at a time.
    func composed(_ functions: [String]) -> String {
        "import Foundation\n\npublic enum \(declares): \(declares)Contract {\n" + functions.map { body in
            body.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "" : "    " + $0 }.joined(separator: "\n")
        }.joined(separator: "\n\n") + "\n}\n"
    }
}
