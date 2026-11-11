//  WHAT: Every file code writes for a port, by the template's names: the surface, the contracts, the domain types, the
//        test runners, and a stub for each unit and handler whose port has not landed.
//  IN:   A PortSpec; which units and commands are ported (their bodies are the port's, not code's).
//  OUT:  The port loop's work tree ("skeleton green" is these files with every body a stub), assembly.
//  PIN:  A PURE FUNCTION. The same spec and the same set of ported names write the same files, byte for byte.

import Foundation

public enum SkeletonCodegen {
    /// Generated files, template path → text. `ported` names the units and commands whose bodies the port supplies;
    /// every other unit and command gets a stub.
    public static func files(_ spec: PortSpec, ported: Swift.Set<String> = []) -> [String: String] {
        var files = SurfaceCodegen.files(spec)
        for unit in spec.units {
            files[SkeletonLayout.contract(unit.unit)] = CoreCodegen.contract(unit)
            if !ported.contains(unit.unit) { files[SkeletonLayout.logic(unit.unit)] = CoreCodegen.logicStub(unit) }
        }
        for type in spec.types { files[SkeletonLayout.domain(type.name)] = CoreCodegen.domain(type) }
        for command in spec.commands where !ported.contains(handlerKey(command.name)) {
            files[SkeletonLayout.handler(command.name)] = CoreCodegen.handlerStub(command)
        }
        files[SkeletonLayout.vectorCalls] = TestCodegen.vectorCalls(spec)
        files[SkeletonLayout.vectorTests] = TestCodegen.vectorTests(spec)
        files[SkeletonLayout.callTests] = TestCodegen.callTests(spec)
        files[SkeletonLayout.expectedSurface] = TestCodegen.expectedSurface(spec)
        return files
    }

    /// The name a ported handler goes by in `ported`, apart from units.
    public static func handlerKey(_ command: String) -> String { "handler:" + command }

    /// Whether a file's text is a stub.
    public static func isStub(_ text: String) -> Bool { text.hasPrefix(SwiftText.stubMarker) }
}
