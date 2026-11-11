import Foundation

/// The faces that stand in for a family that cannot ship (Resources/FallbackFaces.json): system faces by class and
/// kind, so a generated agent draws a substitute of the right character on any Mac and ships no file.
public struct FallbackFaces: Codable, Sendable, Equatable {
    public var faces: [String: [String]]

    public static func load() -> FallbackFaces {
        guard let data = ForgeResources.url("FallbackFaces.json").flatMap({ try? Data(contentsOf: $0) }),
              let faces = try? JSONDecoder().decode(FallbackFaces.self, from: data) else {
            return FallbackFaces(faces: ["serif": ["Georgia", "Times New Roman"], "sans": ["Helvetica Neue", "Arial"], "mono": ["Menlo", "Courier New"]])
        }
        return faces
    }

    /// The faces for a class ("serif") and kind ("didone"): the kind's own list, else the class's, else sans.
    public func faces(class cls: String?, sub: String? = nil) -> [String] {
        let c = cls ?? "sans"
        if let sub, let list = faces["\(c)/\(sub)"] { return list }
        return faces[c] ?? faces["sans"] ?? ["Helvetica Neue"]
    }

    /// Every face offered, each once.
    public var all: [String] {
        var seen: Set<String> = []
        return faces.keys.sorted().flatMap { faces[$0]! }.filter { seen.insert($0).inserted }
    }
}
