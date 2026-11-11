//  WHAT: A reconciled style held to what the kit needs before it ships: every colour role names a palette colour in
//        both themes, ink and muted ink read on the background (4.5:1) and the accent as display (3:1), text on the
//        accent reads, every face a style bundles and its mark are among the files it carries, and every format has an
//        engine. Each problem is a sentence; any problem stops the run before a package is made.

import Foundation

public enum StyleValidator {
    public static func problems(_ reconciled: ReconciledStyle) -> [String] {
        let style = reconciled.style
        let colour = style.colour
        var problems: [String] = []
        if style.format != DesignerStyle.formatID { problems.append("the style says it is \(style.format), not \(DesignerStyle.formatID).") }
        if style.credit.designer.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("the style credits no designer.") }
        for theme in ["light", "dark"] {
            for role in DesignerStyle.colourRoles where colour.hex(role, theme) == nil {
                problems.append("the \(role) role names no colour of the palette in the \(theme) theme.")
            }
            guard let bg = colour.hex("background", theme) else { continue }
            for (role, target) in [("ink", 4.5), ("inkMuted", 4.5), ("accent", 3.0)] {
                if let fg = colour.hex(role, theme), Contrast.ratio(fg, bg) < target - 0.005 {
                    problems.append("\(role) reads at \(String(format: "%.2f", Contrast.ratio(fg, bg))):1 on the \(theme) background; it needs \(target):1.")
                }
            }
            if let accent = colour.hex("accent", theme), let on = colour.hex("accentInk", theme), Contrast.ratio(on, accent) < 4.5 - 0.005 {
                problems.append("text on the accent reads at \(String(format: "%.2f", Contrast.ratio(on, accent))):1 in the \(theme) theme; it needs 4.5:1.")
            }
        }
        let carried = Set(reconciled.assets.map(\.to))
        for family in style.type.families where family.bundled {
            if family.files.isEmpty { problems.append("\(family.family) is bundled with no files.") }
            for file in family.files where !carried.contains(file) { problems.append("\(family.family)'s \(file) is not among the files the style carries.") }
        }
        if let mark = style.mark, !carried.contains(mark.asset) { problems.append("the mark \(mark.asset) is not among the files the style carries.") }
        for role in DesignerStyle.typeRoles where style.type.roles[role] == nil { problems.append("no face for the \(role) role.") }
        let covered = Set(style.layout.archetypes.flatMap { $0.for.isEmpty ? DesignerStyle.formats : $0.for })
        for format in DesignerStyle.formats where !covered.contains(format) { problems.append("no engine draws the \(format).") }
        return problems
    }
}
