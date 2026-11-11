//  WHAT: A port's package as a pure function of its artefacts: the template stamped with the identity, the generated
//        surface, contracts, types and test runners (a stub for every unit or handler not yet ported), the slot bodies,
//        vectors, calls, carried and lifted files placed as they are, and the template's sample left out.
//  IN:   PortArtefacts, an identity, the template, and extra files (README, PROVENANCE, NOTICE).
//  OUT:  The work tree the port loop builds in, and the clean package `assemble` hands the forge.
//  PIN:  ONE FUNCTION FOR BOTH. The tree the port proved and the tree the person downloads are made the same way, so
//        what was built is what ships; a rename is the same call with another identity.

import CraftedCore
import Foundation

public enum EngineerAssembly {
    public static func plan(template: URL, identity: AgentIdentity, artefacts: PortArtefacts, extra: [String: Data] = [:]) throws -> AssemblyPlan {
        let spec = artefacts.shipped
        let ported = Swift.Set(artefacts.state.ported)
        let generated = SkeletonCodegen.files(spec, ported: ported)
        var verbatim: [String: Data] = extra
        for unit in spec.units where ported.contains(unit.unit) {
            if let body = artefacts.slots[SkeletonLayout.logic(unit.unit)] { verbatim[SkeletonLayout.logic(unit.unit)] = Data(body.utf8) }
        }
        for command in spec.commands where ported.contains(SkeletonCodegen.handlerKey(command.name)) {
            if let body = artefacts.slots[SkeletonLayout.handler(command.name)] { verbatim[SkeletonLayout.handler(command.name)] = Data(body.utf8) }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        for unit in spec.units {
            if var list = artefacts.vectors[unit.unit] {
                list.unit = unit.unit
                verbatim[SkeletonLayout.vectors(unit.unit)] = try encoder.encode(list)
            }
        }
        for command in spec.commands {
            if let call = artefacts.calls[command.name] { verbatim[SkeletonLayout.call(command.name)] = try encoder.encode(call) }
        }
        for resource in spec.resources {
            if let carried = artefacts.carried[resource.name] { verbatim[SkeletonLayout.resource(resource.name)] = Data(carried.text.utf8) }
        }
        for lift in spec.lifts {
            if let lifted = artefacts.lifted[lift.name] { verbatim[SkeletonLayout.lifted(lift.name)] = Data(lifted.text.utf8) }
        }
        // The template's own files in the port's folders are its sample: out, unless this port supplies them.
        let supplied = Swift.Set(generated.keys).union(verbatim.keys)
        let remove = sampleFiles(template).filter { !supplied.contains($0) && !SkeletonLayout.fixedInPortFolders.contains($0) }
        return AssemblyPlan(template: template, identity: identity, generated: generated, verbatim: verbatim, remove: remove)
    }

    /// The template's files in the port's folders, by their template paths.
    static func sampleFiles(_ template: URL) -> [String] {
        var files: [String] = []
        for folder in SkeletonLayout.portFolders {
            let url = template.appendingPathComponent(folder, isDirectory: true)
            guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            let base = url.standardizedFileURL.resolvingSymlinksInPath().path
            for case let file as URL in walker where (try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true {
                let path = file.standardizedFileURL.resolvingSymlinksInPath().path
                guard path.hasPrefix(base + "/") else { continue }
                files.append(folder + "/" + String(path.dropFirst(base.count + 1)))
            }
        }
        return files.sorted()
    }

    /// Assembles into `destination`.
    @discardableResult
    public static func assemble(template: URL, identity: AgentIdentity, artefacts: PortArtefacts, extra: [String: Data] = [:],
                                into destination: URL) throws -> AssembledTree {
        try PackageAssembler.assemble(plan(template: template, identity: identity, artefacts: artefacts, extra: extra), into: destination)
    }
}
