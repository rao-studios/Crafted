//  WHAT: The refusals the router says itself, each a sentence with its fix: no command, an argument missing or out of
//        its values, a path outside the folder, a hand-off that does not read.
//  PIN:  KINDS ARE THE STANDARD'S. A fix the caller can make is `call`; a model that wrote nothing usable is `model`.

import Foundation
import GraniteAgents

enum Refusals {
    /// Every command with its arguments, as one sentence a caller can choose from.
    static var commandList: String {
        "name one of: " + Surface.commands.map { "`\($0.name)` (\($0.arguments.isEmpty ? "no arguments" : $0.arguments.joined(separator: ", "))): \($0.summary)" }
            .joined(separator: "; ") + "."
    }

    static func noCommand(modelOffered: Bool) -> AgentRefusal {
        let why = modelOffered ? "The call names no command and says nothing to read one from" : "The call names no command and this host offers no model to read one from its words"
        return AgentRefusal(.call, "\(why): set `command` and its arguments, \(commandList)")
    }

    static func missing(_ field: String, command: String, note: String) -> AgentRefusal {
        AgentRefusal(.call, "`\(command)` needs `\(field)`: \(note).")
    }

    static func notOneOf(_ field: String, _ value: String, values: [String], command: String) -> AgentRefusal {
        AgentRefusal(.call, "`\(command)` takes `\(field)` as one of \(values.joined(separator: ", ")), not \(value).")
    }

    static func outside(_ path: String) -> AgentRefusal {
        AgentRefusal(.call, "\(path) is outside the project folder: give a path inside it, relative to the project.")
    }

    static func unreadable(_ path: String, _ why: String) -> AgentRefusal {
        AgentRefusal(.call, "\(path) could not be read (\(why)): give a file inside the project that exists.")
    }
}
