//  WHAT: Who the person is, which decides what a dropped folder becomes. A designer's folder becomes a style agent
//        that draws new pieces in their design system; an engineer's project becomes an agent that does what the
//        project does.
//  IN:   The onboarding's role step, Settings › General, Home's role pill (all through PreferencesService).
//  OUT:  The forge picks its pipeline by role; a generation records the role it was made with.

import Foundation

public enum CraftedRole: String, Codable, Sendable, CaseIterable, Identifiable {
    case designer
    case engineer

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .designer: return "Designer"
        case .engineer: return "Engineer"
        }
    }

    /// One sentence for the role pickers.
    public var blurb: String {
        switch self {
        case .designer:
            return "Drop a folder of your work. Crafted reads your design system and makes an agent that draws brochures, posters and cards in your style, with your name on it."
        case .engineer:
            return "Drop a project, in any language. Crafted walks all of it, offers three agents it could become, and ports the one you pick to Swift."
        }
    }

    /// What the drop zone asks for.
    public var dropPrompt: String {
        switch self {
        case .designer: return "Drop a folder of your designs"
        case .engineer: return "Drop a project folder"
        }
    }

    public var symbol: String {
        switch self {
        case .designer: return "paintbrush.pointed"
        case .engineer: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
