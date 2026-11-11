//  WHAT: A motif's CSS, kept to what draws a shape: backgrounds and gradients, borders, radii, opacity, transforms,
//        clip paths, blend modes, shadows and sizes. Anything else (a URL, an import, script, a selector) is dropped.
//  PIN:  A MOTIF NEVER FETCHES. Its CSS was written by a model from what the designer's pieces showed; it may only
//        draw with the page's own variables and gradients, never load a picture.

import Foundation

public enum MotifCSS {
    static let allowed: Set<String> = [
        "background", "background-color", "background-image", "background-size", "background-position", "background-repeat",
        "background-blend-mode", "border", "border-top", "border-right", "border-bottom", "border-left", "border-width",
        "border-style", "border-color", "border-radius", "outline", "opacity", "transform", "rotate", "clip-path",
        "box-shadow", "mix-blend-mode", "width", "height", "inset", "top", "right", "bottom", "left", "filter",
    ]
    static let banned = ["url(", "@", "expression", "javascript", "<", ">", "\\", "{", "}", "image-set", "element(", "attr("]

    /// The declarations of `css` that draw a shape, joined; empty when none survive.
    public static func sanitize(_ css: String) -> String {
        guard css.count <= 1_200 else { return "" }
        var kept: [String] = []
        for declaration in css.split(separator: ";") {
            guard let colon = declaration.firstIndex(of: ":") else { continue }
            let property = declaration[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = declaration[declaration.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard allowed.contains(property), !value.isEmpty, value.count <= 400 else { continue }
            let lowered = value.lowercased()
            guard !banned.contains(where: { lowered.contains($0) }) else { continue }
            kept.append("\(property): \(value)")
        }
        return kept.joined(separator: "; ")
    }

    /// The motif layers a page carries, under its blocks: one element per motif in a page slot. A divider motif styles
    /// the divider blocks instead (`dividerCSS`).
    static func layers(_ book: StyleBook) -> String {
        var html = ""
        for motif in book.style.motifs where ["background", "corner", "frame", "accent"].contains(motif.slot) {
            let css = motif.css.map(sanitize) ?? ""
            let image = book.motifs[motif.id].map { "<img src=\"\($0)\" alt=\"\">" } ?? ""
            guard !css.isEmpty || !image.isEmpty || motif.slot == "accent" else { continue }
            html += "<div class=\"motif slot-\(motif.slot) m-\(PieceHTML.escape(motif.id))\" style=\"\(PieceHTML.escape(css))\">\(image)</div>"
        }
        return html
    }

    /// CSS for divider blocks from the style's divider motif, if it has one.
    static func dividerCSS(_ book: StyleBook) -> String {
        guard let motif = book.style.motifs.first(where: { $0.slot == "divider" }), let css = motif.css.map(sanitize), !css.isEmpty else { return "" }
        return ".b-divider { \(css); }"
    }
}
