//  WHAT: crafted-check's command line, read by hand from CommandLine.arguments (no dependency): the subcommand,
//        its flags (`--name value`, `--switch`), and the one folder it works on.

import Foundation

struct CheckArguments {
    struct Problem: Error, CustomStringConvertible {
        let description: String
    }

    let command: String
    private(set) var values: [String: String] = [:]
    private(set) var switches: Swift.Set<String> = []
    private(set) var positional: [String] = []

    /// `takingValues` names the flags that read the next argument.
    init(_ arguments: [String], takingValues: Swift.Set<String>) throws {
        var rest = Array(arguments.dropFirst())
        guard let command = rest.first, !command.hasPrefix("-") else {
            throw Problem(description: "Name a command: forge, toolchain or validate.")
        }
        self.command = command
        rest.removeFirst()
        var index = 0
        while index < rest.count {
            let argument = rest[index]
            if argument.hasPrefix("--") {
                var name = String(argument.dropFirst(2))
                var inline: String?
                if let equals = name.firstIndex(of: "=") {
                    inline = String(name[name.index(after: equals)...])
                    name = String(name[..<equals])
                }
                if takingValues.contains(name) {
                    if let inline {
                        values[name] = inline
                    } else {
                        guard index + 1 < rest.count else { throw Problem(description: "--\(name) needs a value.") }
                        values[name] = rest[index + 1]
                        index += 1
                    }
                } else {
                    switches.insert(name)
                }
            } else {
                positional.append(argument)
            }
            index += 1
        }
    }

    func value(_ name: String) -> String? { values[name] }
    func has(_ name: String) -> Bool { switches.contains(name) }

    /// The one folder the command works on, as an absolute URL.
    func folder() throws -> URL {
        guard let path = positional.last else { throw Problem(description: "Name a folder.") }
        return Self.url(path)
    }

    static func url(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        let absolute = expanded.hasPrefix("/") ? expanded
            : FileManager.default.currentDirectoryPath + "/" + expanded
        return URL(fileURLWithPath: absolute).standardizedFileURL
    }
}
