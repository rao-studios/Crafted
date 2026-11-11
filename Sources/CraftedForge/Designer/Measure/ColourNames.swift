import Foundation

/// A plain name for a colour, as a person would say it: "near black", "warm white", "deep red", "muted teal". Names
/// help a person reading the style; roles and letters never depend on them.
public enum ColourNames {
    public static func name(_ lab: OKLab) -> String {
        if lab.chroma < 0.025 {
            switch lab.l {
            case ..<0.2: return "near black"
            case ..<0.4: return "charcoal"
            case ..<0.65: return "grey"
            case ..<0.9: return "light grey"
            default: return lab.b > 0.008 ? "cream" : "white"
            }
        }
        var hue = atan2(lab.b, lab.a) * 180 / .pi
        if hue < 0 { hue += 360 }
        let family: String
        switch hue {
        case ..<20, 345...: family = "pink"
        case ..<45: family = "red"
        case ..<70: family = "orange"
        case ..<100: family = "gold"
        case ..<125: family = "yellow"
        case ..<165: family = "green"
        case ..<200: family = "teal"
        case ..<250: family = "blue"
        case ..<290: family = "indigo"
        default: family = "violet"
        }
        if lab.chroma < 0.05 { return (lab.l > 0.8 ? "warm white" : lab.l < 0.35 ? "dark " : "muted ") + (lab.l > 0.8 ? "" : family) }
        if lab.l < 0.35 { return "deep \(family)" }
        if lab.l > 0.85 { return "pale \(family)" }
        return family
    }
}
