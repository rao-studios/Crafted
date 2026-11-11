import Foundation

/// A style's colour: the palette (each colour once, by id), the roles a page reads (a palette id per theme), its
/// gradients, and how the designer spends colour.
public struct StyleColour: Codable, Sendable, Equatable {
    /// One colour of the palette: an id roles name it by ("A"), its hex, a plain name, its share of the designer's
    /// pieces, how many pieces it appears in, and where it was found (declared, measured, adjusted).
    public struct Entry: Codable, Sendable, Equatable {
        public var id: String
        public var hex: String
        public var name: String?
        public var weight: Double?
        public var pieces: Int?
        public var source: String?

        public init(id: String, hex: String, name: String? = nil, weight: Double? = nil, pieces: Int? = nil, source: String? = nil) {
            self.id = id; self.hex = hex; self.name = name; self.weight = weight; self.pieces = pieces; self.source = source
        }
    }

    /// A role's palette id in each theme.
    public struct Pair: Codable, Sendable, Equatable {
        public var light: String
        public var dark: String?

        public init(light: String, dark: String? = nil) { self.light = light; self.dark = dark }
    }

    public struct Gradient: Codable, Sendable, Equatable {
        public var id: String
        /// Palette ids, first to last.
        public var stops: [String]
        public var angle: Double?

        public init(id: String, stops: [String], angle: Double? = nil) { self.id = id; self.stops = stops; self.angle = angle }
    }

    /// What a page reads. Every role has a fallback, so a style that names only background, ink and accent draws.
    public enum Role: String, Codable, Sendable, CaseIterable {
        case background, surface, ink, inkMuted, accent, accentInk, secondary, rule
    }

    public var grounds: [String]
    public var palette: [Entry]
    public var roles: [String: Pair]
    public var gradients: [Gradient]
    public var proportions: [String: Double]
    public var usage: [String]

    public init(grounds: [String] = ["light"], palette: [Entry], roles: [String: Pair], gradients: [Gradient] = [],
                proportions: [String: Double] = [:], usage: [String] = []) {
        self.grounds = grounds; self.palette = palette; self.roles = roles; self.gradients = gradients
        self.proportions = proportions; self.usage = usage
    }

    enum CodingKeys: String, CodingKey { case grounds, palette, roles, gradients, proportions, usage }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grounds = PieceLoose.list(c, .grounds, of: String.self)
        palette = PieceLoose.list(c, .palette, of: Entry.self).filter { PieceColour.parse($0.hex) != nil }
        roles = (try? c.decodeIfPresent([String: Pair].self, forKey: .roles)) ?? [:]
        gradients = PieceLoose.list(c, .gradients, of: Gradient.self)
        proportions = (try? c.decodeIfPresent([String: Double].self, forKey: .proportions)) ?? [:]
        usage = PieceLoose.list(c, .usage, of: String.self)
        guard !palette.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "the palette holds no colour"))
        }
    }

    public func entry(_ id: String) -> Entry? { palette.first { $0.id == id } }

    /// The hex a role reads in `theme`, from its own pair, else its fallback's.
    public func hex(_ role: Role, _ theme: PieceTheme) -> String {
        if let id = id(role, theme), let entry = entry(id) { return PieceColour.normal(entry.hex) }
        switch role {
        case .background: return theme == .dark ? "#111111" : "#FFFFFF"
        case .ink: return theme == .dark ? "#F2F2F2" : "#111111"
        case .surface: return PieceColour.mix(hex(.background, theme), hex(.ink, theme), 0.06)
        case .inkMuted: return PieceColour.mix(hex(.ink, theme), hex(.background, theme), 0.35)
        case .accent: return hex(.ink, theme)
        case .accentInk: return hex(.background, theme)
        case .secondary: return hex(.accent, theme)
        case .rule: return PieceColour.mix(hex(.ink, theme), hex(.background, theme), 0.75)
        }
    }

    /// The palette id a role names in `theme`. With no dark id, the dark theme swaps background and ink and keeps the
    /// rest, so a style made from light pieces still draws dark.
    public func id(_ role: Role, _ theme: PieceTheme) -> String? {
        guard theme == .dark else { return roles[role.rawValue]?.light }
        if let dark = roles[role.rawValue]?.dark { return dark }
        switch role {
        case .background: return roles[Role.ink.rawValue]?.light
        case .ink: return roles[Role.background.rawValue]?.light
        case .surface, .inkMuted, .rule: return nil
        case .accentInk: return roles[Role.accentInk.rawValue]?.light
        case .accent, .secondary: return roles[role.rawValue]?.light
        }
    }

    /// The theme a piece takes when the call names none: the designer's own ground.
    public var naturalTheme: PieceTheme {
        let dark = grounds.filter { $0 == "dark" }.count
        let light = grounds.filter { $0 == "light" }.count
        if dark > light { return .dark }
        if light > 0 { return .light }
        return PieceColour.luminance(hex(.background, .light)) < 0.2 ? .dark : .light
    }
}
