//  WHAT: Where the two templates are: `CRAFTED_TEMPLATES`, the app's Contents/Resources/Templates (make-app.sh copies
//        them there), or the repository's Templates/ found upward from the executable or the working directory.
//  OUT:  The pipelines' assembly; crafted-check.

import Foundation

public struct TemplateSource: Sendable, Equatable {
    public var root: URL

    public init(root: URL) { self.root = root }

    public func folder(_ kind: TemplateKind) -> URL { root.appendingPathComponent(kind.rawValue, isDirectory: true) }

    public static func locate() -> TemplateSource? {
        let fm = FileManager.default
        func holds(_ folder: URL) -> Bool {
            fm.fileExists(atPath: folder.appendingPathComponent(TemplateKind.engineer.rawValue + "/template.json").path)
                || fm.fileExists(atPath: folder.appendingPathComponent(TemplateKind.designer.rawValue + "/template.json").path)
        }
        if let path = ProcessInfo.processInfo.environment["CRAFTED_TEMPLATES"], !path.isEmpty {
            return TemplateSource(root: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true))
        }
        if let resources = Bundle.main.resourceURL?.appendingPathComponent("Templates", isDirectory: true), holds(resources) {
            return TemplateSource(root: resources)
        }
        var starts = [URL(fileURLWithPath: fm.currentDirectoryPath)]
        if let executable = Bundle.main.executableURL { starts.append(executable.deletingLastPathComponent()) }
        for start in starts {
            var folder = start
            for _ in 0..<8 {
                let candidate = folder.appendingPathComponent("Templates", isDirectory: true)
                if holds(candidate) { return TemplateSource(root: candidate) }
                folder = folder.deletingLastPathComponent()
            }
        }
        return nil
    }
}
