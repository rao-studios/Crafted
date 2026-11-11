//  WHAT: PROVENANCE.md: every file of the package with where it came from (the template, code generated from the plan,
//        the coder's port of named source lines, a file carried or lifted as it was) and how it is verified; then every
//        file of the source project that was not ported, and why.

import CraftedCore
import Foundation

enum ProvenanceWriter {
    static func text(identity: AgentIdentity, tree: AssembledTree, plan: AssemblyPlan, artefacts: PortArtefacts, project: ProjectRecord,
                     template: URL) -> String {
        let spec = artefacts.shipped
        var origin: [String: (how: String, from: String, check: String)] = [:]
        func stamped(_ path: String) -> String { (try? PackageAssembler.stampedPath(path, template: template, identity: identity)) ?? path }
        for path in plan.generated.keys { origin[stamped(path)] = ("generated", "the plan (commands.json, unit contracts)", "compiled") }
        for unit in spec.units {
            let record = artefacts.state.records[unit.unit]
            let check = record.map { "\($0.sourceVectors) source-test and \($0.derivedVectors) derived vectors pass (\($0.heldOut) held out of the port); \($0.attempts) attempt\($0.attempts == 1 ? "" : "s")" } ?? "not ported"
            origin[stamped(SkeletonLayout.logic(unit.unit))] = ("ported", unit.evidence.joined(separator: ", "), check)
            origin[stamped(SkeletonLayout.vectors(unit.unit))] = ("written from the source", unit.evidence.joined(separator: ", "), "recomputed and run")
        }
        for command in spec.commands {
            let record = artefacts.state.records[SkeletonCodegen.handlerKey(command.name)]
            origin[stamped(SkeletonLayout.handler(command.name))] = ("ported", "use cases " + command.usecases.joined(separator: ", "),
                                                                     record?.status == "passed" ? "its canonical call answers" : "not checked")
            origin[stamped(SkeletonLayout.call(command.name))] = ("written from the source", "the project's examples and tests", "run")
        }
        for resource in spec.resources { origin[stamped(SkeletonLayout.resource(resource.name))] = ("carried", resource.source, "read by the logic's vectors") }
        for lift in spec.lifts { origin[stamped(SkeletonLayout.lifted(lift.name))] = ("lifted", lift.source, "compiled") }
        var lines = ["# Provenance", "", "\(identity.display) was made by Crafted from **\(project.title)** (`\(project.folder)`), choosing the interpretation \"\(project.card.name)\" (\(project.card.archetype.rawValue)).", ""]
        lines += ["## Every file", "", "| File | How | From | Verified |", "| --- | --- | --- | --- |"]
        for file in tree.files.sorted() where !file.hasPrefix("Assets/") {
            let entry = origin[file] ?? (file.hasSuffix(".md") || file == "NOTICE" ? ("written for this package", "the run", "—") : ("template", "EngineerAgentSkeleton", "the template's own tests"))
            lines.append("| `\(file)` | \(entry.how) | \(entry.from) | \(entry.check) |")
        }
        let used = Swift.Set(spec.units.flatMap(\.evidence).compactMap { Evidence.parse($0)?.path } + spec.resources.map(\.source) + spec.lifts.map(\.source))
        let unported = project.files.filter { !used.contains($0.key) }.sorted { $0.key < $1.key }
        if !unported.isEmpty {
            lines += ["", "## Not ported", "", "| Source file | Why |", "| --- | --- |"]
            for (path, verdict) in unported {
                let why: String
                switch verdict {
                case FileVerdict.read.rawValue: why = "read, and not part of the chosen interpretation"
                case FileVerdict.test.rawValue: why = "a test: its cases became vectors where they apply"
                case FileVerdict.manifest.rawValue, FileVerdict.doc.rawValue: why = "read for the brief"
                default: why = verdict
                }
                lines.append("| `\(path)` | \(why) |")
            }
        }
        for dropped in artefacts.state.dropped { lines.append("\nThe `\(dropped.command)` command was dropped: \(dropped.why).") }
        return lines.joined(separator: "\n") + "\n"
    }
}
