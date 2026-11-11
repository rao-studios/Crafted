//  WHAT: A style with everything it draws with, read once: style.json, its bundled faces as @font-face sources, the
//        designer's mark and its motif assets as data URLs, so a page fetches nothing and draws the same anywhere.
//  IN:   A Style folder: the package's own (AtelierResources), or any folder that holds a style.json (tests).
//  OUT:  StyleCSS, the engines (the mark, motifs), the loop (the style's voice for the draft).

import Foundation

public struct StyleBook: Sendable {
    public let style: AtelierStyle
    public let folder: URL?
    public let faces: [StyleFace]
    /// The mark's data URL, when the style has one and its file was found.
    public let mark: String?
    /// A motif's id → its asset's data URL.
    public let motifs: [String: String]
    /// Assets the style names that were not found: drawn without, said in the answer.
    public let missing: [String]

    public init(style: AtelierStyle, folder: URL?, faces: [StyleFace] = [], mark: String? = nil, motifs: [String: String] = [:], missing: [String] = []) {
        self.style = style; self.folder = folder; self.faces = faces; self.mark = mark; self.motifs = motifs; self.missing = missing
    }

    /// The style in `folder` (a folder holding style.json, Fonts/, Marks/, Motifs/).
    public static func load(folder: URL) throws -> StyleBook {
        let url = folder.appendingPathComponent("style.json")
        guard let data = try? Data(contentsOf: url) else { throw PieceError.style("no style.json in \(folder.path)") }
        let style = try AtelierStyle.read(data)
        var missing: [String] = []
        var faces: [StyleFace] = []
        for family in style.type.families where family.bundled {
            for file in family.files {
                let path = folder.appendingPathComponent(file)
                if let face = StyleFace.read(path, family: family.family) { faces.append(face) } else { missing.append(file) }
            }
        }
        var mark: String?
        if let asset = style.mark?.asset {
            mark = dataURL(folder.appendingPathComponent(asset))
            if mark == nil { missing.append(asset) }
        }
        var motifs: [String: String] = [:]
        for motif in style.motifs {
            guard let asset = motif.asset else { continue }
            if let url = dataURL(folder.appendingPathComponent(asset)) { motifs[motif.id] = url } else { missing.append(asset) }
        }
        return StyleBook(style: style, folder: folder, faces: faces, mark: mark, motifs: motifs, missing: missing)
    }

    /// A picture file as a data URL: SVG, PNG, JPEG, WebP or a PDF's first page as it is.
    public static func dataURL(_ url: URL, limit: Int = 6_000_000) -> String? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty, data.count <= limit else { return nil }
        let type: String
        switch url.pathExtension.lowercased() {
        case "svg": type = "image/svg+xml"
        case "png": type = "image/png"
        case "jpg", "jpeg": type = "image/jpeg"
        case "webp": type = "image/webp"
        case "gif": type = "image/gif"
        default: return nil
        }
        return "data:\(type);base64," + data.base64EncodedString()
    }
}
