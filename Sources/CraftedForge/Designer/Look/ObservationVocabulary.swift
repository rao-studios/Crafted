import Foundation

/// The closed lists every observation's value comes from. The look prompt shows them; ObservationCheck holds an answer
/// to them. "unsure" is always allowed.
public enum ObservationVocabulary {
    public static let pieceKinds: Set<String> = ["poster", "flyer", "brochure-page", "onepager", "socialcard", "story", "businesscard", "slide",
                                                 "banner", "book-cover", "packaging", "menu", "invitation", "web-page", "logo-sheet", "photo",
                                                 "illustration", "other"]
    public static let confidence: Set<String> = ["low", "medium", "high"]
    public static let grounds: Set<String> = ["light", "dark", "photo", "colour", "mixed"]
    public static let structures: Set<String> = ["hero", "split", "column", "grid", "band", "centre", "type-only", "frame", "collage"]
    public static let alignments: Set<String> = ["left", "centre", "right", "justified", "mixed"]
    public static let margins: Set<String> = ["none", "tight", "regular", "generous"]
    public static let densities: Set<String> = ["sparse", "balanced", "dense"]
    public static let symmetries: Set<String> = ["symmetric", "asymmetric"]
    public static let positions: Set<String> = ["top", "middle", "bottom", "left", "right"]
    public static let scales: Set<String> = ["modest", "large", "huge"]
    public static let cases: Set<String> = ["upper", "lower", "title", "sentence", "mixed"]
    public static let treatments: Set<String> = ["plain", "outlined", "underlined", "boxed", "rotated", "stacked"]
    public static let emphases: Set<String> = ["size", "weight", "colour", "case", "space"]
    public static let typeRoles: Set<String> = ["display", "heading", "body", "caption", "label", "numeral"]
    public static let typeClasses: Set<String> = ["serif", "sans", "slab", "mono", "script", "display"]
    public static let typeSubs: Set<String> = ["geometric", "grotesque", "neo-grotesque", "humanist", "didone", "transitional", "old-style",
                                               "condensed", "extended", "rounded", "stencil", "blackletter", "handwritten", "none"]
    public static let weights: Set<String> = ["thin", "light", "regular", "medium", "bold", "black"]
    public static let widths: Set<String> = ["condensed", "normal", "extended"]
    public static let slants: Set<String> = ["upright", "italic"]
    public static let trackings: Set<String> = ["tight", "normal", "loose"]
    public static let contrasts: Set<String> = ["low", "medium", "high"]
    public static let imageryKinds: Set<String> = ["photo", "illustration", "pattern", "texture", "icon", "chart", "none"]
    public static let imageryTreatments: Set<String> = ["full-bleed", "framed", "duotone", "monochrome", "cutout", "tinted", "none"]
    public static let shares: Set<String> = ["none", "small", "half", "most"]
    public static let motifKinds: Set<String> = ["rule", "shape", "pattern", "texture", "line", "grain", "gradient", "frame"]
    public static let motifPlaces: Set<String> = ["background", "corner", "edge", "divider", "frame", "behind-headline"]
    public static let corners: Set<String> = ["square", "soft", "round", "pill"]
    public static let strokes: Set<String> = ["none", "hairline", "regular", "heavy"]
    public static let shadows: Set<String> = ["none", "soft", "hard"]
    public static let fills: Set<String> = ["flat", "gradient", "textured"]
    public static let moods: Set<String> = ["calm", "bold", "playful", "serious", "luxurious", "minimal", "warm", "cool", "raw", "elegant",
                                            "technical", "retro", "futuristic", "organic", "loud", "quiet", "festive", "austere"]
    public static let markKinds: Set<String> = ["designer-mark", "client-logo", "stock-watermark"]
    public static let markPlaces: Set<String> = ["top-left", "top-right", "bottom-left", "bottom-right", "centre", "top", "bottom"]
    public static let people: Set<String> = ["none", "some", "many"]

    /// Faces a model may not name: a typeface is classified, never named, so a style never claims one it cannot ship.
    public static let typefaces: [String] = [
        "helvetica", "futura", "garamond", "baskerville", "bodoni", "didot", "gill sans", "avenir", "akzidenz", "univers", "frutiger",
        "times", "arial", "inter", "roboto", "playfair", "montserrat", "lato", "open sans", "caslon", "georgia", "verdana", "gotham",
        "proxima", "din", "eurostile", "optima", "rockwell", "clarendon", "franklin gothic", "neue haas", "circular", "brandon",
        "canela", "gt america", "graphik", "tiempos", "freight", "minion", "myriad", "source sans", "ibm plex", "space grotesk",
        "velour grotesk",
    ]
}
