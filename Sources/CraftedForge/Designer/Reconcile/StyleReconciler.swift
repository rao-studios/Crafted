//  WHAT: The style, reconciled by code from everything the run learned: every value from the most trusted source that
//        has one (declared, measured, observed, inferred), what nothing fixed derived from what did, every text colour
//        brought to its contrast (4.5:1 for ink, 3:1 for display) by moving its lightness, and every decision written
//        into the style's provenance.
//  IN:   ReconcileInputs (measures, the looks' consensus, rights, the five synthesis answers, fallback faces).
//  OUT:  A ReconciledStyle: crafted-style/1 and the files it ships (cleared faces and their licences, the mark).
//  PIN:  NO MODEL. Reconcile is code from artefacts, so the same run reconciles to the same style.

import Foundation

public enum StyleReconciler {
    public static func reconcile(_ input: ReconcileInputs) -> ReconciledStyle {
        var decisions = input.rights.notes
        var palette = input.measures.palette.map {
            DesignerStyle.Entry(id: $0.id, hex: $0.hex, name: $0.name, weight: rounded($0.weight), pieces: $0.pieces, source: $0.source)
        }
        let roles = colourRoles(input, palette: &palette, decisions: &decisions)
        let (type, assets) = typeSystem(input, decisions: &decisions)
        var allAssets = assets
        let space = self.space(input)
        let shape = self.shape(input)
        let layout = self.layout(input, decisions: &decisions)
        let imagery = self.imagery(input)
        let motifs = self.motifs(input)
        var mark: DesignerStyle.Mark?
        if let path = input.rights.mark {
            let file = "Marks/" + (path as NSString).lastPathComponent
            allAssets.append(.init(from: path, to: file))
            let placement = LookConsensus.vote(input.consensus.looks.flatMap { $0.marks.filter { $0.what == "designer-mark" }.map(\.where) })
            mark = DesignerStyle.Mark(asset: file, placement: ["top-left", "top-right", "bottom-left", "bottom-right"].contains(placement ?? "") ? placement! : "top-right")
        }
        let grounds = input.inventory.distinct.compactMap { input.measures.pieces[$0.id]?.ground }
        let colour = DesignerStyle.Colour(grounds: grounds, palette: palette, roles: roles,
                                          gradients: (input.synthesis.colour?.gradients ?? []).filter { $0.stops.allSatisfy { stop in palette.contains { $0.id == stop } } },
                                          proportions: Dictionary(uniqueKeysWithValues: palette.filter { ($0.weight ?? 0) > 0 }.map { ($0.id, $0.weight ?? 0) }),
                                          usage: input.synthesis.colour?.usage ?? [])
        let style = DesignerStyle(
            format: DesignerStyle.formatID, name: input.name,
            credit: .init(designer: input.rights.designer, url: input.rights.url, line: nil, colophon: "default-on", styleLicence: "CC-BY-4.0"),
            colour: colour, type: type, space: space, shape: shape, layout: layout, imagery: imagery, motifs: motifs, mark: mark,
            voice: voice(input),
            provenance: .init(pieces: input.inventory.distinct.count, looked: input.consensus.looks.count, models: ["vision", "coder"], decisions: decisions))
        return ReconciledStyle(style: style, assets: allAssets)
    }

    // MARK: Colour

    /// The theme the folder's pieces stand on: dark when most are.
    static func naturalTheme(_ measures: DesignMeasures) -> String {
        (measures.grounds["dark"] ?? 0) > (measures.grounds["light"] ?? 0) + (measures.grounds["colour"] ?? 0) ? "dark" : "light"
    }

    static func colourRoles(_ input: ReconcileInputs, palette: inout [DesignerStyle.Entry], decisions: inout [String]) -> [String: DesignerStyle.Pair] {
        let measures = input.measures
        let natural = naturalTheme(measures)
        let other = natural == "light" ? "dark" : "light"
        let letters = Set(palette.map(\.id))
        var declared: [String: String] = [:]
        for colour in measures.declared.colours {
            guard let role = colour.role, declared[role] == nil, let letter = palette.first(where: { $0.hex == colour.hex })?.id else { continue }
            declared[role] = letter
        }
        var chosen: [String: [String: (String, TrustOrder.Source)]] = [:]
        for role in DesignerStyle.colourRoles {
            for theme in ["light", "dark"] {
                let inferredPair = input.synthesis.colour?.roles[role]
                let inferred = (theme == "dark" ? inferredPair?.dark : inferredPair?.light).flatMap { letters.contains($0) ? $0 : nil }
                // A declared role is the designer's natural theme's; an accent is every theme's.
                let declaredHere = theme == natural || role == "accent" || role == "secondary" ? declared[role] : nil
                if let pick = TrustOrder.pick(declared: declaredHere, measured: measures.roles[role]?[theme],
                                              observed: input.consensus.colour(role, theme: theme), inferred: inferred) {
                    chosen[role, default: [:]][theme] = pick
                }
            }
        }
        // The theme the pieces never show: background and ink swapped from the natural one when nothing chose them.
        func letter(_ role: String, _ theme: String) -> String? { chosen[role]?[theme]?.0 }
        if letter("background", other) == nil || letter("ink", other) == nil || letter("background", other) == letter("ink", other) {
            if let bg = letter("ink", natural), let ink = letter("background", natural) {
                chosen["background", default: [:]][other] = (bg, .inferred)
                chosen["ink", default: [:]][other] = (ink, .inferred)
                decisions.append("The designer's pieces are \(natural): the \(other) theme swaps their background and ink.")
            }
        }
        func hex(_ id: String?) -> String? { id.flatMap { id in palette.first { $0.id == id }?.hex } }
        func add(_ hexValue: String, name: String, source: String) -> String {
            if let same = palette.first(where: { $0.hex == hexValue }) { return same.id }
            let used = Set(palette.map(\.id))
            let id = (DesignMeasures.letters + DesignMeasures.letters.map { $0 + "2" }).first { !used.contains($0) } ?? "Z\(palette.count)"
            palette.append(.init(id: id, hex: hexValue, name: name, weight: 0, pieces: 0, source: source))
            return id
        }
        var roles: [String: DesignerStyle.Pair] = [:]
        for theme in ["light", "dark"] {
            let background = letter("background", theme) ?? add(theme == "dark" ? "#141414" : "#FFFFFF", name: theme == "dark" ? "night" : "white", source: "derived")
            var ink = letter("ink", theme) ?? add(theme == "dark" ? "#F2F2F2" : "#141414", name: theme == "dark" ? "white" : "near black", source: "derived")
            if background == ink { ink = add(theme == "dark" ? "#F2F2F2" : "#141414", name: "ink", source: "derived") }
            let bgHex = hex(background)!, inkHex = hex(ink)!
            func mix(_ a: String, _ b: String, _ t: Double) -> String {
                guard let x = OKLab(hex: a), let y = OKLab(hex: b) else { return a }
                return OKLab(l: x.l + (y.l - x.l) * t, a: x.a + (y.a - x.a) * t, b: x.b + (y.b - x.b) * t).hex
            }
            var accent = letter("accent", theme) ?? ink
            let surface = letter("surface", theme) ?? add(mix(bgHex, inkHex, 0.06), name: "surface", source: "derived")
            var muted = letter("inkMuted", theme) ?? add(mix(inkHex, bgHex, 0.35), name: "muted ink", source: "derived")
            let secondary = letter("secondary", theme) ?? accent
            let rule = letter("rule", theme) ?? add(mix(inkHex, bgHex, 0.75), name: "rule", source: "derived")
            // Contrast: ink and muted ink read as text (4.5:1); the accent reads as display (3:1); text on the accent reads.
            func bring(_ id: String, _ role: String, _ target: Double, against ground: String) -> String {
                let current = hex(id)!
                let ratio = Contrast.ratio(current, ground)
                guard ratio < target else { return id }
                let fixed = Contrast.adjusted(current, against: ground, target: target)
                let newID = add(fixed, name: (palette.first { $0.id == id }?.name ?? role) + " (adjusted)", source: "adjusted")
                decisions.append("\(role) \(id) \(current) on \(theme) background read at \(String(format: "%.1f", ratio)):1; adjusted to \(fixed) (\(String(format: "%.1f", Contrast.ratio(fixed, ground))):1).")
                return newID
            }
            ink = bring(ink, "ink", 4.5, against: bgHex)
            muted = bring(muted, "inkMuted", 4.5, against: bgHex)
            accent = bring(accent, "accent", 3, against: bgHex)
            let accentHex = hex(accent)!
            let accentInk = letter("accentInk", theme).flatMap { Contrast.ratio(hex($0)!, accentHex) >= 4.5 ? $0 : nil }
                ?? [background, ink].max { Contrast.ratio(hex($0)!, accentHex) < Contrast.ratio(hex($1)!, accentHex) }!
            let readableInk = bring(accentInk, "accentInk", 4.5, against: accentHex)
            for (role, id) in [("background", background), ("surface", surface), ("ink", ink), ("inkMuted", muted), ("accent", accent),
                               ("accentInk", readableInk), ("secondary", secondary), ("rule", rule)] {
                var pair = roles[role] ?? DesignerStyle.Pair(light: id, dark: nil)
                if theme == "light" { pair.light = id } else { pair.dark = id }
                roles[role] = pair
            }
        }
        let sources = DesignerStyle.colourRoles.compactMap { role -> String? in
            guard let (letter, source) = chosen[role]?[natural] else { return nil }
            return "\(role) \(letter) (\(source.rawValue))"
        }
        if !sources.isEmpty { decisions.append("Colour roles in the \(natural) theme: " + sources.joined(separator: ", ") + ".") }
        return roles
    }

    // MARK: Type

    static func typeSystem(_ input: ReconcileInputs, decisions: inout [String]) -> (DesignerStyle.TypeSystem, [ReconciledStyle.Asset]) {
        let measures = input.measures, consensus = input.consensus, fallbacks = input.fallbacks
        let system = Set(fallbacks.all.map { $0.lowercased() })
        let cleared = input.rights.cleared
        let clearedNames = Set(cleared.map { $0.family.lowercased() })
        var families: [DesignerStyle.Family] = []
        var assets: [ReconciledStyle.Asset] = []
        for font in cleared {
            let files = font.files.map { "Fonts/" + ($0 as NSString).lastPathComponent }
            assets += zip(font.files, files).map { .init(from: $0, to: $1) }
            if let licence = font.licenceFile { assets.append(.init(from: licence, to: "Fonts/" + (licence as NSString).lastPathComponent)) }
            families.append(.init(family: font.family, licence: font.licence, bundled: true, files: files))
        }
        var substituted: Set<String> = []
        func resolve(_ family: String, cls: String?, sub: String?) -> (family: String, source: String, original: String?) {
            if clearedNames.contains(family.lowercased()) { return (cleared.first { $0.family.lowercased() == family.lowercased() }!.family, "bundled", nil) }
            if system.contains(family.lowercased()) { return (fallbacks.all.first { $0.lowercased() == family.lowercased() }!, "system", nil) }
            let stand = fallbacks.faces(class: cls, sub: sub).first ?? "Helvetica Neue"
            return (stand, "fallback", family)
        }
        var roles: [String: DesignerStyle.Role] = [:]
        for role in DesignerStyle.typeRoles {
            let observedClass = consensus.typeClass(role) ?? consensus.typeClass(role == "numeral" ? "display" : role == "label" || role == "caption" ? "body" : "display")
            let observedSub = consensus.typeValue(role) { $0.sub }
            let declaredFace = measures.declared.faces.first { $0.role == role }?.family
                ?? (role == "numeral" ? measures.declared.faces.first { $0.role == "display" }?.family : nil)
                ?? (role == "caption" || role == "label" ? measures.declared.faces.first { $0.role == "body" }?.family : nil)
            let measuredFace = cleared.first { font in measures.fonts.first { $0.family == font.family }?.class == observedClass }?.family
            let observedFace = observedClass.map { fallbacks.faces(class: $0, sub: observedSub).first ?? "Helvetica Neue" }
            let inferredAnswer = input.synthesis.type?.roles[role]
            let pick = TrustOrder.pick(declared: declaredFace, measured: measuredFace, observed: observedFace, inferred: inferredAnswer?.family)
            let wanted = pick?.value ?? "Helvetica Neue"
            let cls = observedClass ?? inferredAnswer?.class ?? measures.fonts.first { $0.family == wanted }?.class ?? "sans"
            let resolved = resolve(wanted, cls: cls, sub: observedSub)
            if let original = resolved.original, substituted.insert(original).inserted {
                decisions.append("\(original) is declared but not in the folder and cannot ship: \(resolved.family) stands in (\(cls)).")
            }
            if resolved.source != "bundled", !families.contains(where: { $0.family == resolved.family }) {
                families.append(.init(family: resolved.family, licence: "system", bundled: false, files: []))
            }
            let slant = consensus.typeValue(role) { $0.slant }
            let style = slant == "italic" ? "italic" : slant == "upright" ? "normal" : (inferredAnswer?.style == "italic" ? "italic" : "normal")
            let weightWord = consensus.typeValue(role) { $0.weight }
            let weight = weightWord.map(cssWeight) ?? inferredAnswer?.weight ?? (role == "display" || role == "numeral" ? 700 : role == "label" ? 600 : 400)
            let headlineCase = role == "display" ? consensus.vote { $0.hierarchy.headline.case } : nil
            let textCase = headlineCase.map { $0 == "upper" ? "upper" : $0 == "lower" ? "lower" : "none" } ?? inferredAnswer?.textCase ?? (role == "label" ? "upper" : "none")
            let trackingWord = consensus.typeValue(role) { $0.tracking }
            let tracking = trackingWord.map { $0 == "tight" ? -0.02 : $0 == "loose" ? 0.08 : 0 } ?? inferredAnswer?.tracking ?? (role == "label" ? 0.1 : 0)
            let leading = inferredAnswer?.leading ?? (role == "display" ? 1.0 : role == "heading" ? 1.15 : role == "body" ? 1.45 : 1.3)
            let stand = fallbacks.faces(class: cls, sub: observedSub).filter { $0 != resolved.family }
            roles[role] = DesignerStyle.Role(family: resolved.family, source: resolved.source, fallbacks: Array(stand.prefix(2)), class: cls,
                                             weight: min(max(weight, 100), 900), style: style, textCase: textCase,
                                             tracking: min(max(tracking, -0.05), 0.3), leading: min(max(leading, 0.9), 1.8))
        }
        let scaleWord = consensus.vote { $0.hierarchy.headline.scale }
        let ratio = TrustOrder.pick(observed: scaleWord.map { $0 == "huge" ? 1.333 : $0 == "large" ? 1.25 : 1.2 }, inferred: input.synthesis.type?.ratio)?.value ?? 1.25
        return (DesignerStyle.TypeSystem(families: families, roles: roles, scale: .init(base: 16, ratio: min(max(ratio, 1.125), 1.6))), assets)
    }

    static func cssWeight(_ word: String) -> Int {
        ["thin": 200, "light": 300, "regular": 400, "medium": 500, "bold": 700, "black": 900][word] ?? 400
    }

    // MARK: Space, shape, layout, imagery, motifs, voice

    static func space(_ input: ReconcileInputs) -> DesignerStyle.Space {
        let m = input.measures.margins
        let side = m.isEmpty ? 0.07 : min(m[0], m[2])
        let margin = min(max(side > 0.005 ? side : 0.07, 0.03), 0.14)
        let ink = input.measures.ink
        let measuredDensity = ink > 0.35 ? "dense" : ink < 0.12 ? "sparse" : "balanced"
        let density = TrustOrder.pick(measured: nil as String?, observed: input.consensus.vote { $0.layout.density },
                                      inferred: input.synthesis.layout?.density)?.value ?? measuredDensity
        return .init(unit: 8, scale: [0.5, 1, 1.5, 2, 3, 4, 6, 8], pageMargin: rounded(margin), gutter: rounded(margin * 0.45),
                     density: ["sparse", "balanced", "dense"].contains(density) ? density : "balanced")
    }

    static func shape(_ input: ReconcileInputs) -> DesignerStyle.Shape {
        let c = input.consensus
        let radius: Double = ["square": 0, "soft": 4, "round": 12, "pill": 24][c.vote { $0.shape.corners } ?? "square"] ?? 0
        let stroke: Double = ["none": 0, "hairline": 1, "regular": 2, "heavy": 4][c.vote { $0.shape.strokes } ?? "hairline"] ?? 1
        return .init(radius: radius, stroke: stroke, shadow: c.vote { $0.shape.shadows } ?? "none", fills: c.vote { $0.shape.fills } ?? "flat")
    }

    static func layout(_ input: ReconcileInputs, decisions: inout [String]) -> DesignerStyle.Layout {
        let c = input.consensus, answer = input.synthesis.layout
        let alignment = TrustOrder.pick(observed: c.vote { $0.layout.alignment }.flatMap { ["left", "centre", "right"].contains($0) ? $0 : nil },
                                        inferred: answer?.alignment)?.value ?? "left"
        let symmetry = TrustOrder.pick(observed: c.vote { $0.layout.symmetry }, inferred: answer?.symmetry)?.value ?? "asymmetric"
        let seenColumns = c.looks.map(\.layout.columns).filter { $0 > 0 }.sorted()
        let columns = TrustOrder.pick(observed: seenColumns.isEmpty ? nil : seenColumns[seenColumns.count / 2], inferred: answer?.columns)?.value ?? 2
        var rules = (answer?.archetypes ?? []).filter { DesignerStyle.engines.contains($0.engine) }.map { rule -> DesignerStyle.Rule in
            var rule = rule
            rule.for = rule.for.filter { DesignerStyle.formats.contains($0) }
            rule.weight = min(max(rule.weight, 0.1), 2)
            return rule
        }
        if rules.isEmpty {
            // Nothing inferred: the engines the pieces were seen to use, weighted by how often.
            var counts: [String: Int] = [:]
            let engineOf = ["hero": "hero", "centre": "hero", "type-only": "hero", "band": "hero", "split": "split", "frame": "split",
                            "column": "column", "grid": "grid", "collage": "grid"]
            for look in c.looks { if let engine = engineOf[look.layout.structure] { counts[engine, default: 0] += 1 } }
            let total = Double(max(counts.values.reduce(0, +), 1))
            rules = counts.keys.sorted().map { .init(engine: $0, for: [], weight: rounded(0.5 + Double(counts[$0]!) / total), headline: nil, image: nil) }
        }
        let defaults = ["poster": "hero", "flyer": "split", "brochure": "column", "onepager": "column", "socialcard": "hero", "story": "hero",
                        "businesscard": "split", "slide": "split", "banner": "hero"]
        let covered = Set(rules.flatMap { $0.for.isEmpty ? DesignerStyle.formats : $0.for })
        for format in DesignerStyle.formats where !covered.contains(format) {
            rules.append(.init(engine: defaults[format]!, for: [format], weight: 1, headline: nil, image: nil))
            decisions.append("No engine was chosen for the \(format): it takes the \(defaults[format]!).")
        }
        return .init(alignment: alignment == "center" ? "centre" : alignment, symmetry: symmetry, grid: .init(columns: min(max(columns, 1), 4)), archetypes: rules)
    }

    static func imagery(_ input: ReconcileInputs) -> DesignerStyle.Imagery {
        let c = input.consensus, answer = input.synthesis.imagery
        let seenKinds = Array(Set(c.looks.flatMap(\.imagery.kinds)).subtracting(["unsure", "none"])).sorted()
        let seenTreatment = c.vote { $0.imagery.treatment }.flatMap { $0 == "none" ? nil : $0 }
        let placeholder = answer?.placeholder.flatMap { ["solid", "gradient", "duotone", "pattern"].contains($0) ? $0 : nil }
            ?? (seenTreatment == "duotone" ? "duotone" : c.vote { $0.shape.fills } == "gradient" ? "gradient" : "solid")
        return .init(kinds: seenKinds.isEmpty ? (answer?.kinds ?? []) : seenKinds,
                     treatments: seenTreatment.map { [$0] } ?? (answer?.treatments ?? []), rules: answer?.rules ?? [], placeholder: placeholder)
    }

    static func motifs(_ input: ReconcileInputs) -> [DesignerStyle.Motif] {
        (input.synthesis.imagery?.motifs ?? []).compactMap { motif in
            guard ["background", "corner", "divider", "frame", "accent"].contains(motif.slot) else { return nil }
            var motif = motif
            motif.css = motif.css.map(MotifSafety.sanitize).flatMap { $0.isEmpty ? nil : $0 }
            motif.asset = nil
            return motif.css == nil && motif.slot != "accent" ? nil : motif
        }.prefix(4).map { $0 }
    }

    static func voice(_ input: ReconcileInputs) -> DesignerStyle.Voice {
        let read = Set(input.measures.words.map { $0.lowercased() })
        if let answer = input.synthesis.voice {
            return .init(tone: answer.tone, headline: answer.headline, vocabulary: answer.vocabulary ?? [], avoid: answer.avoid ?? [],
                         samples: (answer.samples ?? []).filter { read.contains($0.lowercased()) })
        }
        var moods: [String: Int] = [:]
        for mood in input.consensus.looks.flatMap(\.mood) where mood != "unsure" { moods[mood, default: 0] += 1 }
        return .init(tone: moods.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(3).map(\.key),
                     headline: nil, vocabulary: [], avoid: [], samples: Array(input.measures.words.prefix(3)))
    }

    static func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
}
