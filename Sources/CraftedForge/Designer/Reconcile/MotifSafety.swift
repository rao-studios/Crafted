//  WHAT: The motif CSS the forge keeps, by the same rule as the kit's MotifCSS (Templates/DesignerAgentTemplate/
//        Sources/AtelierKit/Kit/MotifCSS.swift): declarations that draw a shape, with the page's own variables; never a
//        URL, an import, script or a selector. The forge checks a model's motif here before it reaches style.json; the
//        kit sanitises again when it draws.

import Foundation

public enum MotifSafety {
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
}
