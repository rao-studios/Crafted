//  WHAT: The order the walk cards a project's source files in: leaves first along the import graph (a file after the
//        files it imports, so its card can lean on theirs), entry files last and whole.
//  PIN:  CYCLES DO NOT STOP THE WALK. A cycle is broken at its first file by path, and every file is still carded once.

import Foundation

public struct ImportGraph: Sendable, Equatable {
    /// Each file's project imports.
    public var imports: [String: [String]]
    /// Files that are entered (a main, an argument parser, a route).
    public var entries: Swift.Set<String>

    public init(imports: [String: [String]], entries: Swift.Set<String>) { self.imports = imports; self.entries = entries }

    /// The graph of `inventory`'s source files.
    public static func of(_ inventory: Inventory) -> ImportGraph {
        let sources = inventory.with(.read)
        let paths = Swift.Set(inventory.files.filter { $0.verdict.isOpened }.map(\.path))
        var imports: [String: [String]] = [:]
        var entries: Swift.Set<String> = []
        for file in sources {
            let rules = (file.language ?? .other).rules
            let lines = inventory.lines(file.path)
            imports[file.path] = rules.imports(lines, path: file.path, paths: paths).filter { $0 != file.path }
            if rules.effects(lines).contains(where: { $0.kind == "entry" }) { entries.insert(file.path) }
        }
        return ImportGraph(imports: imports, entries: entries)
    }

    /// Leaves first; entry files last.
    public var order: [String] {
        var placed: [String] = []
        var seen: Swift.Set<String> = []
        func visit(_ path: String, _ stack: Swift.Set<String>) {
            guard !seen.contains(path), !stack.contains(path) else { return }
            for next in (imports[path] ?? []).sorted() where imports[next] != nil { visit(next, stack.union([path])) }
            if seen.insert(path).inserted { placed.append(path) }
        }
        for path in imports.keys.sorted() where !entries.contains(path) { visit(path, []) }
        for path in imports.keys.sorted() where entries.contains(path) { visit(path, []) }
        let rest = placed.filter { !entries.contains($0) }
        return rest + placed.filter { entries.contains($0) }
    }
}
