//  WHAT: The package's README, in the shape Rao's agents keep (DesignAgent's): what it does, what you can ask, what
//        you get, how it works, what was ported and what was not with each command's verification level, how to get
//        it, what it needs, and where developers read on.
//  PIN:  HONEST. A command that was dropped is named with why; a command's verification level is said as it is.

import CraftedCore
import Foundation

enum ReadmeWriter {
    static func text(identity: AgentIdentity, listing: AgentListing, artefacts: PortArtefacts, project: ProjectRecord) -> String {
        let spec = artefacts.shipped
        let word = identity.word
        var lines = ["# \(identity.display)", ""]
        lines.append(listing.tagline.isEmpty ? capitalised(spec.summary) : listing.tagline)
        lines += ["", "It \(spec.summary.hasSuffix(".") ? spec.summary : spec.summary + ".") Ported to Swift by Crafted from **\(project.title)**, and checked against that project's own behaviour.", ""]
        lines += ["## What you can ask", "", "```"]
        for command in spec.commands {
            let args = (artefacts.calls[command.name]?.input ?? [:]).filter { $0.key != "command" }.sorted { $0.key < $1.key }
                .map { "\($0.key) \($0.value.scalarDescription ?? $0.value.compact)" }.joined(separator: ", ")
            lines.append("$\(word) \(command.name)" + (args.isEmpty ? "" : ": \(args)"))
        }
        lines += ["```", "", "Craft's model writes the call from what you ask; a call can also name its `command` and arguments as JSON.", ""]
        lines += ["## What you get", ""]
        for command in spec.commands {
            let makes = command.produces.map { "\($0.kind) \"\($0.name)\"" }.joined(separator: ", ")
            lines.append("- **`\(command.name)`**: \(command.summary)" + (makes.isEmpty ? "" : " Makes \(makes)."))
        }
        lines += ["", "Every call can be presented as output (files), for Canvas (pictures, paged PDFs and series) or as context: one `crafted-handoff/1` file the next agent's call takes as `handoff`.", ""]
        lines += ["## How it works", ""]
        lines.append("- Each command reads its arguments, runs logic ported from the source project, and writes what it made under `\(word)/` (or the call's `output` folder). The answer names every file and says what it found.")
        lines.append("- The logic is plain Swift with Foundation only (the `\(identity.coreTarget)` target): no network, no other processes, no secrets.")
        lines.append("- A call it cannot honour is refused with the fix, and nothing is written.")
        lines += ["", "## What was ported and what was not", ""]
        lines.append("| Command | Verification |")
        lines.append("| --- | --- |")
        for line in artefacts.state.verification(artefacts.spec) {
            let parts = line.components(separatedBy: " · ")
            lines.append("| `\(parts.first ?? line)` | \(parts.dropFirst().joined(separator: " · ")) |")
        }
        let left = project.card.leavesOut.map { "- \($0.what): \($0.why)" } + artefacts.state.dropped.map { "- The `\($0.command)` command: \($0.why). It was dropped rather than shipped untested." }
        if !left.isEmpty { lines += ["", "Left out:", ""] + left }
        lines += ["", "PROVENANCE.md maps every file to the source it came from and how it got there.", ""]
        lines += ["## Get it", "", "In Craft, install \(identity.display) from the Agent Store, or run `craft agents add <this repository's URL>`, then say `$\(word)` in a request.", ""]
        lines += ["## Requirements", "", "- A Mac on macOS 26 or later.", "- \(listing.license.rawValue) licensed. See NOTICE for the source project.", ""]
        lines += ["## For developers", "", "The agent standard it follows is Granite's [granite-agent/1](https://github.com/riteshpakala/Granite/blob/main/Schema/GraniteAgent.md). "
            + "`swift test` runs every unit's vectors and every command's canonical call.", ""]
        return lines.joined(separator: "\n")
    }

    static func capitalised(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }
}
