//  WHAT: The style as CSS: its colours as role variables for the theme, each type role as a face stack with its weight,
//        style, case, tracking and leading, a type scale sized to the page, its space and shapes, the bundled faces as
//        @font-face rules, and the blocks' own styles, which read only those variables.
//  IN:   A StyleBook, the format, the page's size, the theme.
//  OUT:  PieceKit (every page), the tests (computed fonts and colours equal the style's roles).
//  PIN:  BLOCKS READ VARIABLES, NEVER VALUES. Nothing below `:root` names a colour, a family or a size, so a piece drawn
//        in another style is that style's piece, and the tests can hold a page's computed values to the style.

import Foundation

public enum StyleCSS {
    /// The page's sizes, from the style's scale and the format: the unit is the body's size on this page.
    public struct Metrics: Sendable, Equatable {
        public let unit: Double
        public let ratio: Double
        public let margin: Double
        public let gutter: Double
        public let gap: Double

        public init(style: AtelierStyle, format: PieceFormat, size: PieceSize) {
            let scale = size.shortSide / format.size.shortSide
            unit = style.type.scale.base * format.typeFactor * scale
            ratio = style.type.scale.ratio
            margin = (size.shortSide * style.space.pageMargin).rounded()
            gutter = (size.shortSide * style.space.gutter).rounded()
            gap = (unit * 0.9 * style.space.flow).rounded()
            self.size = size
        }

        let size: PieceSize

        func step(_ n: Double) -> Double { unit * pow(ratio, n) }
        var caption: Double { max(unit * 0.78, 9) }
        var lead: Double { step(1) }
        var subhead: Double { step(2) }
        var heading: Double { step(2.5) }
        var headline: Double { min(step(4.2), size.shortSide * 0.12) }
        var display: Double { min(max(step(5.6), size.shortSide * 0.12), size.shortSide * 0.19) }
        var stat: Double { min(step(4.6), size.shortSide * 0.13) }
    }

    public static func css(_ book: StyleBook, format: PieceFormat, size: PieceSize, theme: PieceTheme) -> String {
        let style = book.style
        let colour = style.colour
        let m = Metrics(style: style, format: format, size: size)
        func px(_ value: Double) -> String { PieceHTML.n(value) + "px" }
        var root: [String] = []
        for role in StyleColour.Role.allCases {
            root.append("--\(variable(role)): \(colour.hex(role, theme))")
        }
        // Small type in the accent only when it reads; otherwise in ink. Display type (a figure) needs 3:1.
        let background = colour.hex(.background, theme)
        root.append("--kicker: " + (PieceColour.contrast(colour.hex(.accent, theme), background) >= 4.5 ? "var(--accent)" : "var(--ink)"))
        root.append("--figure: " + (PieceColour.contrast(colour.hex(.accent, theme), background) >= 3 ? "var(--accent)" : "var(--ink)"))
        // A split's colour field: the style's gradient only when the words set on it (the accent's ink) read on every
        // stop of it; else the accent, which reconcile holds to 4.5:1 against that ink.
        let panelInk = colour.hex(.accentInk, theme)
        let panel = colour.gradients.first { gradient in
            let stops = gradient.stops.compactMap { colour.entry($0)?.hex }
            return stops.count >= 2 && stops.allSatisfy { PieceColour.contrast($0, panelInk) >= 3 }
        }
        root.append("--panel: " + (panel.map { gradient($0, colour, theme) } ?? "var(--accent)"))
        for name in StyleType.RoleName.allCases {
            let role = style.type.role(name)
            let key = name.rawValue
            root.append("--f-\(key): \(stack(role))")
            root.append("--w-\(key): \(role.weight)")
            root.append("--st-\(key): \(role.style)")
            root.append("--tt-\(key): \(transform(role.textCase))")
            root.append("--ls-\(key): \(PieceHTML.n4(role.tracking))em")
            root.append("--lh-\(key): \(PieceHTML.n4(role.leading))")
        }
        // Every size is a multiple of the page's `--grow`, which the page's script raises until the page is full.
        func grown(_ value: Double) -> String { "calc(var(--grow) * \(px(value)))" }
        root += [
            "--grow: 1",
            "--s-caption: \(grown(m.caption))", "--s-body: \(grown(m.unit))", "--s-lead: \(grown(m.lead))", "--s-subhead: \(grown(m.subhead))",
            "--s-heading: \(grown(m.heading))", "--s-headline: \(grown(m.headline))", "--s-display: \(grown(m.display))", "--s-stat: \(grown(m.stat))",
            "--margin: \(px(m.margin))", "--gutter: \(px(m.gutter))", "--gap: \(grown(m.gap))",
            "--radius: \(px(style.shape.radius * size.shortSide / 850))", "--stroke: \(px(max(style.shape.stroke, 0.5)))",
            "--shadow: \(style.shape.boxShadow)", "--align: \(style.layout.textAlign)",
            "--page-w: \(px(size.width))", "--page-h: \(px(size.height))",
        ]
        let variables = root
        let faces = book.faces.map(\.css).joined(separator: "\n")
        return faces + "\n:root { " + variables.joined(separator: "; ") + "; }\n" + base
    }

    /// How far the page's type may grow to fill it: a sparse style keeps its air, a dense one fills its page.
    public static func growCeiling(_ style: AtelierStyle) -> Double {
        switch style.space.density {
        case "sparse": return 1.15
        case "dense": return 1.5
        default: return 1.35
        }
    }

    static func variable(_ role: StyleColour.Role) -> String {
        switch role {
        case .background: return "bg"
        case .surface: return "surface"
        case .ink: return "ink"
        case .inkMuted: return "ink-muted"
        case .accent: return "accent"
        case .accentInk: return "accent-ink"
        case .secondary: return "secondary"
        case .rule: return "rule"
        }
    }

    /// A family name as CSS may quote it: no quotes, backslashes, semicolons or braces.
    public static func familyName(_ family: String) -> String {
        String(family.filter { !"\"'\\;{}<>".contains($0) }.prefix(64)).trimmingCharacters(in: .whitespaces)
    }

    /// The role's family, its stand-ins, and the generic family its class falls back to.
    static func stack(_ role: StyleType.Role) -> String {
        var names = [role.family] + role.fallbacks
        names = names.map(familyName).filter { !$0.isEmpty }
        var seen: Set<String> = []
        names = names.filter { seen.insert($0.lowercased()).inserted }
        let generics: Set<String> = ["serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui"]
        let quoted = names.map { generics.contains($0.lowercased()) ? $0.lowercased() : "\"\($0)\"" }
        let generic = genericFamily(role.class)
        return (quoted + (quoted.contains(generic) ? [] : [generic])).joined(separator: ", ")
    }

    static func genericFamily(_ cls: String?) -> String {
        switch cls ?? "" {
        case "serif", "slab", "didone": return "serif"
        case "mono": return "monospace"
        case "script": return "cursive"
        default: return "sans-serif"
        }
    }

    static func transform(_ textCase: String) -> String {
        switch textCase {
        case "upper": return "uppercase"
        case "lower": return "lowercase"
        case "title": return "capitalize"
        default: return "none"
        }
    }

    static func gradient(_ gradient: StyleColour.Gradient, _ colour: StyleColour, _ theme: PieceTheme) -> String {
        let stops = gradient.stops.compactMap { colour.entry($0)?.hex }.map(PieceColour.normal)
        guard stops.count >= 2 else { return "var(--accent)" }
        return "linear-gradient(\(PieceHTML.n(gradient.angle ?? 135))deg, \(stops.joined(separator: ", ")))"
    }

    /// The page and every block, in variables only. A size is `calc(var(--fit) * var(--s-…))`, so a zone's fit
    /// shrinks its type and nothing else.
    static let base = """
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; width: var(--page-w); height: var(--page-h); overflow: hidden; background: var(--bg); }
    body { color: var(--ink); font-family: var(--f-body); font-weight: var(--w-body); font-style: var(--st-body);
           -webkit-font-smoothing: antialiased; text-rendering: optimizeLegibility; font-kerning: normal; font-variant-ligatures: common-ligatures; }
    .page { position: relative; width: var(--page-w); height: var(--page-h); padding: var(--margin); display: flex; flex-direction: column;
            gap: var(--gap); overflow: hidden; background: var(--bg); text-align: var(--align); isolation: isolate; }
    .zone { position: relative; z-index: 2; min-height: 0; min-width: 0; display: flex; flex-direction: column; gap: calc(var(--gap) * var(--fit)); overflow: hidden; }
    .blk { margin: 0; min-width: 0; overflow-wrap: break-word; }
    .b-headline { font-family: var(--f-display); font-weight: var(--w-display); font-style: var(--st-display); text-transform: var(--tt-display);
                  letter-spacing: var(--ls-display); line-height: var(--lh-display); font-size: calc(var(--fit) * var(--s-headline));
                  overflow-wrap: normal; word-break: normal; hyphens: manual; color: var(--ink); text-wrap: balance; }
    .b-kicker { font-family: var(--f-label); font-weight: var(--w-label); font-style: var(--st-label); text-transform: var(--tt-label);
                letter-spacing: var(--ls-label); line-height: var(--lh-label); font-size: calc(var(--fit) * var(--s-caption) * 1.1); color: var(--kicker); }
    .b-subhead { font-family: var(--f-heading); font-weight: var(--w-heading); font-style: var(--st-heading); text-transform: var(--tt-heading);
                 letter-spacing: var(--ls-heading); line-height: var(--lh-heading); font-size: calc(var(--fit) * var(--s-subhead)); text-wrap: balance; }
    .b-lead { font-size: calc(var(--fit) * var(--s-lead)); line-height: var(--lh-body); }
    .b-body { font-size: calc(var(--fit) * var(--s-body)); line-height: var(--lh-body); }
    .b-body p { margin: 0 0 calc(var(--fit) * var(--s-body) * 0.7); } .b-body p:last-child { margin-bottom: 0; }
    .bt { font-family: var(--f-heading); font-weight: var(--w-heading); font-style: var(--st-heading); text-transform: var(--tt-heading);
          letter-spacing: var(--ls-heading); line-height: 1.2; font-size: calc(var(--fit) * var(--s-lead)); margin-bottom: calc(var(--fit) * var(--s-body) * 0.5); }
    .b-list ul, .b-steps ol { list-style: none; margin: 0; padding: 0; text-align: left; }
    .b-list li, .b-steps li { font-size: calc(var(--fit) * var(--s-body)); line-height: var(--lh-body); position: relative; }
    .b-list li { padding-left: 1.1em; } .b-list li + li, .b-steps li + li { margin-top: calc(var(--fit) * var(--s-body) * 0.35); }
    .b-list li::before { content: ""; position: absolute; left: 0.1em; top: 0.62em; width: 0.42em; height: 0.42em; background: var(--accent); border-radius: min(var(--radius), 0.21em); }
    .b-steps li { display: flex; gap: 0.7em; align-items: baseline; }
    .b-steps .n { font-family: var(--f-numeral); font-weight: var(--w-numeral); color: var(--figure); min-width: 1.4em; font-variant-numeric: tabular-nums lining-nums; }
    .b-stat .fig { font-family: var(--f-numeral); font-weight: var(--w-numeral); font-style: var(--st-numeral); letter-spacing: var(--ls-numeral);
                   font-size: calc(var(--fit) * var(--s-stat)); line-height: 0.95; color: var(--figure); font-variant-numeric: lining-nums; }
    .b-stat .cap { font-size: calc(var(--fit) * var(--s-body)); line-height: var(--lh-body); color: var(--ink-muted); margin-top: 0.3em; }
    .b-quote { margin: 0; }
    .b-quote blockquote { margin: 0; font-family: var(--f-heading); font-weight: var(--w-heading); font-style: var(--st-heading);
                          font-size: calc(var(--fit) * var(--s-subhead)); line-height: 1.25; text-wrap: balance; }
    .b-quote figcaption { margin-top: 0.6em; font-family: var(--f-label); text-transform: var(--tt-label); letter-spacing: var(--ls-label);
                          font-size: calc(var(--fit) * var(--s-caption)); color: var(--ink-muted); }
    .b-callout { background: var(--surface); border: var(--stroke) solid var(--rule); border-radius: var(--radius); box-shadow: var(--shadow);
                 padding: calc(var(--fit) * var(--s-body) * 1.1); font-size: calc(var(--fit) * var(--s-body)); line-height: var(--lh-body); text-align: left; }
    .b-callout p { margin: 0; }
    .b-details { margin: 0; display: grid; grid-template-columns: auto 1fr; column-gap: 1.2em; row-gap: 0.35em; text-align: left;
                 font-size: calc(var(--fit) * var(--s-body)); line-height: var(--lh-body); }
    .b-details dt { font-family: var(--f-label); font-weight: var(--w-label); text-transform: var(--tt-label); letter-spacing: var(--ls-label);
                    color: var(--ink-muted); font-size: 0.82em; padding-top: 0.12em; }
    .b-details dd { margin: 0; }
    .b-table { border-collapse: collapse; width: 100%; font-size: calc(var(--fit) * var(--s-body) * 0.92); line-height: 1.3; text-align: left; table-layout: fixed; }
    .b-table th { font-family: var(--f-label); font-weight: var(--w-label); text-transform: var(--tt-label); letter-spacing: var(--ls-label);
                  font-size: 0.85em; color: var(--ink-muted); border-bottom: var(--stroke) solid var(--ink); padding: 0.35em 0.5em 0.35em 0; }
    .b-table td { border-bottom: var(--stroke) solid var(--rule); padding: 0.4em 0.5em 0.4em 0; vertical-align: top; overflow-wrap: break-word; }
    .b-image { margin: 0; display: flex; flex-direction: column; min-height: calc(var(--s-body) * 6); flex: 1 1 auto; }
    .b-image .ph { flex: 1 1 auto; min-height: calc(var(--s-body) * 5); border-radius: var(--radius); overflow: hidden; position: relative; background: var(--surface); }
    .b-image img { width: 100%; height: 100%; object-fit: cover; display: block; position: absolute; inset: 0; }
    .b-image figcaption { font-family: var(--f-caption); font-size: calc(var(--fit) * var(--s-caption)); color: var(--ink-muted); margin-top: 0.5em; text-align: left; }
    .b-image .ph.ph-solid { background: var(--surface); border: var(--stroke) solid var(--rule); }
    .b-image .ph.ph-gradient { background: var(--panel); }
    .b-image .ph.ph-duotone { background: radial-gradient(circle at 32% 38%, var(--secondary) 0 26%, transparent 26.5%), var(--accent); }
    .b-image .ph.ph-pattern { background: repeating-linear-gradient(45deg, var(--rule) 0 2px, transparent 2px 16px), var(--surface); }
    .b-cta { display: flex; flex-wrap: wrap; align-items: center; gap: 0.6em 1em; font-size: calc(var(--fit) * var(--s-body)); justify-content: var(--justify, flex-start); }
    .b-cta .btn { display: inline-block; background: var(--accent); color: var(--accent-ink); border-radius: var(--radius); padding: 0.55em 1.1em;
                  font-family: var(--f-label); font-weight: var(--w-label); text-transform: var(--tt-label); letter-spacing: var(--ls-label); }
    .b-cta .where { color: var(--ink-muted); }
    .b-logo { font-family: var(--f-display); font-weight: var(--w-display); font-size: calc(var(--fit) * var(--s-lead)); letter-spacing: var(--ls-display); }
    .b-logo img { height: calc(var(--fit) * var(--s-lead) * 1.8); width: auto; display: block; }
    .b-divider { border: 0; border-top: var(--stroke) solid var(--rule); height: 0; width: 100%; flex: none; }
    .b-footer { font-family: var(--f-caption); font-weight: var(--w-caption); font-size: calc(var(--fit) * var(--s-caption)); line-height: 1.35; color: var(--ink-muted); }
    .colophon { position: absolute; z-index: 5; bottom: calc(var(--margin) * 0.3); font-family: var(--f-caption); font-size: clamp(8px, calc(var(--margin) * 0.26), 15px);
                line-height: 1.2; color: var(--ink-muted); white-space: nowrap; letter-spacing: 0.02em; }
    .colophon.right { right: var(--margin); } .colophon.left { left: var(--margin); }
    .mark { position: absolute; z-index: 5; height: max(16px, calc(var(--margin) * 0.55)); width: auto; }
    .mark.top-right { top: calc(var(--margin) * 0.22); right: calc(var(--margin) * 0.22); } .mark.top-left { top: calc(var(--margin) * 0.22); left: calc(var(--margin) * 0.22); }
    .mark.bottom-left { bottom: calc(var(--margin) * 0.22); left: calc(var(--margin) * 0.22); } .mark.bottom-right { bottom: calc(var(--margin) * 0.22); right: calc(var(--margin) * 0.22); }
    .motif { position: absolute; z-index: 1; pointer-events: none; }
    .motif img { width: 100%; height: 100%; object-fit: contain; display: block; }
    .slot-background { inset: 0; } .slot-frame { inset: calc(var(--margin) * 0.45); }
    .slot-corner { top: 0; right: 0; width: calc(var(--page-w) * 0.22); height: calc(var(--page-w) * 0.22); }
    .slot-accent { left: var(--margin); top: calc(var(--margin) * 0.55); width: calc(var(--page-w) * 0.16); height: calc(var(--stroke) * 4); background: var(--accent); }
    """
}
