import Foundation

/// The project's modules, by code: its source files grouped by folder, with the folders each imports.
public struct ModuleMap: Codable, Sendable, Equatable {
    public struct Module: Codable, Sendable, Equatable {
        public var name: String
        public var files: [String]
        public var imports: [String]
    }

    public var modules: [Module]

    public static func of(_ graph: ImportGraph) -> ModuleMap {
        func folder(_ path: String) -> String {
            let parent = (path as NSString).deletingLastPathComponent
            return parent.isEmpty ? "." : parent
        }
        let grouped = Dictionary(grouping: graph.imports.keys, by: folder)
        let modules = grouped.keys.sorted().map { name -> Module in
            let files = (grouped[name] ?? []).sorted()
            let imports = Swift.Set(files.flatMap { graph.imports[$0] ?? [] }.map(folder)).subtracting([name])
            return Module(name: name, files: files, imports: imports.sorted())
        }
        return ModuleMap(modules: modules)
    }

    public var digest: String {
        modules.map { "\($0.name): \($0.files.count) files" + ($0.imports.isEmpty ? "" : ", imports \($0.imports.joined(separator: ", "))") }
            .joined(separator: "\n")
    }
}
