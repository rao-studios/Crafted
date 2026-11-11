import Foundation

/// A folder of its own for one test, removed with the process's temporary files.
enum Folder {
    static func make() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("piece-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
