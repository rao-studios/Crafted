//  WHAT: The agent's surface, written from commands.json: the command enum, the flat all-optional input (the commands'
//        fields, then `brief`, `handoff`, `present`, `output`, `seed`, `directory`), a choice enum per choice field, an
//        arguments struct per command that reads and checks its fields, the dispatch table, and the `Surface` the agent
//        declares itself by (summary, fields, guide, makes).
//  OUT:  SkeletonCodegen.
//  PIN:  BYTE-STABLE. The same spec writes the same bytes; the template's sample is held to it by a drift test.

import Foundation

enum SurfaceCodegen {
    /// The fields every command shares, after the commands' own, with their notes.
    static let sharedFields: [(name: String, type: String, note: String)] = [
        ("brief", "String", "what the person wants, in their words, when `command` is left out: the host's model reads it into a command"),
        ("handoff", "String", "a crafted-handoff/1 file an upstream agent wrote, relative to the project, for the command to start from"),
        ("present", "Presentation", "how the results are written: output (files, the default), canvas (pictures, paged PDFs and series Canvas shows) or context (one hand-off file for the next agent)"),
        ("output", "String", "the folder the files go in, relative to the project: skeletonword/ when left out"),
        ("seed", "Int", "the seed for anything random: the same seed makes the same result"),
    ]

    static func swiftType(_ argument: ArgumentSpec, inInput: Bool) -> String {
        switch argument.type {
        case "integer": return "Int"
        case "number": return "Double"
        case "boolean": return "Bool"
        case "choice": return inInput ? SwiftText.pascal(argument.name) + "Choice" : "String"
        case "[string]": return "[String]"
        case "[number]": return "[Double]"
        default: return "String"
        }
    }

    static func files(_ spec: PortSpec) -> [String: String] {
        var files: [String: String] = [:]
        files[SkeletonLayout.commandEnum] = commandEnum(spec)
        files[SkeletonLayout.input] = input(spec)
        for field in spec.fields where field.type == "choice" { files[SkeletonLayout.choice(field.name)] = choice(field) }
        for command in spec.commands { files[SkeletonLayout.arguments(command.name)] = arguments(command, spec: spec) }
        files[SkeletonLayout.dispatch] = dispatch(spec)
        files[SkeletonLayout.surface] = surface(spec)
        return files
    }

    // MARK: Files

    static func commandEnum(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\n\n"
        text += "/// The agent's commands. A call names one in `command`.\n"
        text += "public enum Command: String, Codable, Sendable, CaseIterable {\n"
        for command in spec.commands {
            text += SwiftText.doc(command.summary, indent: "    ")
            text += "    case \(command.name)\n"
        }
        return text + "}\n"
    }

    static func input(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\n\n"
        text += "/// Every field a call may give, all optional: the command, its arguments (a command checks the ones it needs),\n"
        text += "/// and the fields every command shares. The host fills `directory`.\n"
        text += "public struct AgentInput: Codable, Sendable {\n"
        var members: [(String, String)] = [("command", "Command")]
        text += "    /// Which command to run; left out, the host's model reads one from `brief`.\n"
        text += "    public var command: Command?\n"
        for field in spec.fields {
            let type = swiftType(field, inInput: true)
            text += SwiftText.doc(field.note.isEmpty ? field.name : field.note, indent: "    ")
            text += "    public var \(field.name): \(type)?\n"
            members.append((field.name, type))
        }
        for shared in sharedFields {
            text += SwiftText.doc(shared.note, indent: "    ")
            text += "    public var \(shared.name): \(shared.type)?\n"
            members.append((shared.name, shared.type))
        }
        text += "    /// The host's folder.\n"
        text += "    public var directory: String?\n"
        members.append(("directory", "String"))
        text += "\n    public init(" + members.map { "\($0.0): \($0.1)? = nil" }.joined(separator: ", ") + ") {\n"
        for (name, _) in members { text += "        self.\(name) = \(name)\n" }
        text += "    }\n}\n"
        return text
    }

    static func choice(_ field: ArgumentSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\n\n"
        text += SwiftText.doc("The values `\(field.name)` takes.")
        text += "public enum \(SwiftText.pascal(field.name))Choice: String, Codable, Sendable, CaseIterable {\n"
        for value in field.values ?? [] {
            text += SwiftText.isPlainCase(value) ? "    case \(value)\n" : "    case \(SwiftText.caseName(value)) = \(SwiftText.literal(value))\n"
        }
        return text + "}\n"
    }

    static func arguments(_ command: CommandSpec, spec: PortSpec) -> String {
        let type = SwiftText.pascal(command.name) + "Arguments"
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\n\n"
        text += SwiftText.doc("The arguments of `\(command.name)`, read from the call and checked: \(command.summary)")
        text += "public struct \(type): Sendable {\n"
        for argument in command.args {
            text += SwiftText.doc(argument.note.isEmpty ? argument.name : argument.note, indent: "    ")
            text += "    public var \(argument.name): \(swiftType(argument, inInput: false))\(argument.required ? "" : "?")\n"
        }
        if !command.args.isEmpty {
            text += "\n    public init(" + command.args.map { "\($0.name): \(swiftType($0, inInput: false))\($0.required ? "" : "? = nil")" }
                .joined(separator: ", ") + ") {\n"
            for argument in command.args { text += "        self.\(argument.name) = \(argument.name)\n" }
            text += "    }\n"
        } else {
            text += "\n    public init() {}\n"
        }
        text += "\n    /// Reads the call's fields, refusing a missing one or a value the command does not take.\n"
        text += "    public init(from input: AgentInput) throws {\n"
        let union = Dictionary(spec.fields.map { ($0.name, $0.values ?? []) }, uniquingKeysWith: { first, _ in first })
        for argument in command.args {
            let note = argument.note.isEmpty ? "the \(argument.name)" : argument.note
            let source = argument.type == "choice" ? "input.\(argument.name)?.rawValue" : "input.\(argument.name)"
            if argument.required {
                text += "        guard let \(argument.name) = \(source) else {\n"
                text += "            throw Refusals.missing(\(SwiftText.literal(argument.name)), command: \(SwiftText.literal(command.name)), note: \(SwiftText.literal(note)))\n"
                text += "        }\n"
            } else {
                text += "        let \(argument.name) = \(source)\n"
            }
            if argument.type == "choice", let values = argument.values, values != union[argument.name] {
                let list = "[" + values.map(SwiftText.literal).joined(separator: ", ") + "]"
                let bound = argument.required ? argument.name : "\(argument.name) ?? \(SwiftText.literal(values.first ?? ""))"
                text += "        if !\(list).contains(\(bound)) {\n"
                text += "            throw Refusals.notOneOf(\(SwiftText.literal(argument.name)), \(bound), values: \(list), command: \(SwiftText.literal(command.name)))\n"
                text += "        }\n"
            }
            text += "        self.\(argument.name) = \(argument.name)\n"
        }
        if command.args.isEmpty { text += "        _ = input\n" }
        text += "    }\n}\n"
        return text
    }

    static func dispatch(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\n\n"
        text += "/// Each command to its handler, with its arguments read and checked first.\n"
        text += "enum Dispatch {\n"
        text += "    static func run(_ command: Command, _ input: AgentInput, _ kit: CommandKit) async throws -> [Product] {\n"
        text += "        switch command {\n"
        for command in spec.commands {
            let name = SwiftText.pascal(command.name)
            text += "        case .\(command.name): return try await \(name)Handler.run(\(name)Arguments(from: input), kit)\n"
        }
        text += "        }\n    }\n}\n"
        return text
    }

    static func surface(_ spec: PortSpec) -> String {
        var text = SwiftText.generatedHeader + "\n\nimport Foundation\nimport GraniteAgents\n\n"
        text += "/// What the agent says of itself: its summary, a note per field, its guide, what it makes, its commands.\n"
        text += "enum Surface {\n"
        text += "    static let summary = \(SwiftText.literal(spec.summary))\n\n"
        text += "    static let fields: [String: String] = [\n"
        text += "        \"command\": \(SwiftText.literal("which command to run: " + spec.commands.map(\.name).joined(separator: ", ") + "; left out, the host's model reads one from brief")),\n"
        for field in spec.fields {
            text += "        \(SwiftText.literal(field.name)): \(SwiftText.literal(field.note.isEmpty ? field.name : field.note)),\n"
        }
        for shared in sharedFields { text += "        \(SwiftText.literal(shared.name)): \(SwiftText.literal(shared.note)),\n" }
        text += "    ]\n\n"
        text += "    static let guide = [\n"
        for paragraph in guideParagraphs(spec) { text += "        \(SwiftText.literal(paragraph)),\n" }
        text += "    ].joined(separator: \"\\n\\n\")\n\n"
        text += "    static let makes: [AgentMake] = [\n"
        for make in makes(spec) {
            text += "        AgentMake(kind: \(SwiftText.literal(make.kind)), what: \(SwiftText.literal(make.what)),\n"
            text += "                  into: [\"skeletonword/*\"], never: \(SwiftText.literal(make.never))),\n"
        }
        text += "    ]\n\n"
        text += "    static let commands: [CommandEntry] = [\n"
        for command in spec.commands {
            text += "        CommandEntry(name: \(SwiftText.literal(command.name)), arguments: [" + command.args.map { SwiftText.literal($0.name) }.joined(separator: ", ")
                + "],\n                     summary: \(SwiftText.literal(command.summary))),\n"
        }
        text += "    ]\n\n"
        text += "    /// How a command's products are written when the call does not say.\n"
        text += "    static func presentation(_ command: Command) -> Presentation {\n        switch command {\n"
        for command in spec.commands { text += "        case .\(command.name): return .\(presentation(command))\n" }
        text += "        }\n    }\n\n"
        text += "    /// What a command's call asks for: the files it promises, by kind and name.\n"
        text += "    static func expected(_ command: String) -> [AgentExpected] {\n        switch command {\n"
        for command in spec.commands {
            let files = command.produces.filter { ProduceSpec.fileKinds.contains($0.kind) && $0.kind != "handoff" }
            text += "        case \(SwiftText.literal(command.name)): return [" + files.map {
                "AgentExpected(kind: \(SwiftText.literal($0.kind)), name: \(SwiftText.literal($0.name)))"
            }.joined(separator: ", ") + "]\n"
        }
        text += "        default: return []\n        }\n    }\n\n"
        text += "    /// What the host's model is told when it reads a request into a call.\n"
        text += "    static let interpreterSystem = \(SwiftText.literal(interpreterSystem(spec)))\n"
        text += "}\n"
        return text
    }

    // MARK: Words

    static func presentation(_ command: CommandSpec) -> String {
        ["output", "canvas", "context"].contains(command.present) ? command.present : "output"
    }

    static func describe(_ argument: ArgumentSpec) -> String {
        var type = argument.type
        if argument.type == "choice", let values = argument.values { type = values.joined(separator: " | ") }
        let need = argument.required ? ", required" : ""
        return "`\(argument.name)` (\(type)\(need))" + (argument.note.isEmpty ? "" : ": \(argument.note)")
    }

    static func guideParagraphs(_ spec: PortSpec) -> [String] {
        var paragraphs: [String] = []
        if !spec.guide.isEmpty { paragraphs.append(spec.guide) }
        for command in spec.commands {
            var line = "`\(command.name)`: \(command.summary)"
            if !command.args.isEmpty { line += " Takes " + command.args.map(describe).joined(separator: "; ") + "." }
            paragraphs.append(line)
        }
        paragraphs.append("Name the command in `command`; left out, the host's model reads one from `brief`. Every command also takes "
            + "`present` (output, canvas or context), `output` (the folder, skeletonword/ when left out), `seed`, and `handoff` "
            + "(a crafted-handoff/1 file another agent wrote). The answer names every file it wrote in `paths` and says what it "
            + "found in `facts`; a call it cannot honour is refused with the fix, and nothing is written.")
        return paragraphs
    }

    struct Make { var kind: String; var what: String; var never: String }

    static func makes(_ spec: PortSpec) -> [Make] {
        var kinds: [String] = []
        for command in spec.commands {
            for produce in command.produces where ProduceSpec.fileKinds.contains(produce.kind) && !kinds.contains(produce.kind) {
                kinds.append(produce.kind)
            }
        }
        if !kinds.contains("handoff") { kinds.append("handoff") }
        return kinds.map { kind in
            let names = spec.commands.flatMap { command in command.produces.filter { $0.kind == kind }.map(\.name) }
            let of = names.isEmpty ? "" : " (" + names.joined(separator: ", ") + ")"
            switch kind {
            case "text": return Make(kind: kind, what: "texts in Markdown" + of, never: "source code or files outside its folder")
            case "json": return Make(kind: kind, what: "results as JSON" + of, never: "files outside its folder")
            case "csv": return Make(kind: kind, what: "tables as CSV" + of, never: "files outside its folder")
            case "file": return Make(kind: kind, what: "files of its own making" + of, never: "files outside its folder")
            case "report": return Make(kind: kind, what: "reports: a PNG or paged PDF Canvas shows, or Markdown as output" + of,
                                       never: "HTML or SVG")
            case "series": return Make(kind: kind, what: "craft-timeseries/1 series Canvas draws as charts" + of,
                                       never: "the series inside the answer")
            default: return Make(kind: "handoff", what: "crafted-handoff/1 files for the next agent, when a call is presented as context",
                                 never: "a call to another agent")
            }
        }
    }

    static func interpreterSystem(_ spec: PortSpec) -> String {
        "You read a person's request into one call of the skeletonword agent: answer one JSON object naming `command` and "
            + "its arguments, nothing else. " + spec.summary + " Commands: "
            + spec.commands.map { "`\($0.name)` (" + $0.args.map(\.name).joined(separator: ", ") + "): " + $0.summary }.joined(separator: " ")
    }
}
