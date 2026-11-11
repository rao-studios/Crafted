import Foundation

/// A style's type: the families it uses (bundled, when their licence lets them ship), a face per role, and a scale.
public struct StyleType: Codable, Sendable, Equatable {
    /// A family the style names, and whether its files ship in Resources/Style/Fonts.
    public struct Family: Codable, Sendable, Equatable {
        public var family: String
        /// "OFL-1.1", "Apache-2.0", "attested", "system", "unknown".
        public var licence: String?
        public var bundled: Bool
        /// Paths under Resources/Style: "Fonts/PlayfairDisplay-Italic.ttf".
        public var files: [String]

        public init(family: String, licence: String? = nil, bundled: Bool = false, files: [String] = []) {
            self.family = family; self.licence = licence; self.bundled = bundled; self.files = files
        }

        enum CodingKeys: String, CodingKey { case family, licence, bundled, files }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            family = try c.decode(String.self, forKey: .family)
            licence = PieceLoose.string(c, .licence)
            bundled = PieceLoose.bool(c, .bundled) ?? false
            files = PieceLoose.list(c, .files, of: String.self)
        }
    }

    /// One role's face: its family and the faces that stand in, its class, weight, style, case, tracking (em) and
    /// leading (a multiple of the size).
    public struct Role: Codable, Sendable, Equatable {
        public var family: String
        /// bundled, system, fallback.
        public var source: String?
        public var fallbacks: [String]
        /// serif, sans, slab, mono, script, display.
        public var `class`: String?
        public var weight: Int
        /// normal, italic.
        public var style: String
        /// none, upper, lower, title.
        public var textCase: String
        public var tracking: Double
        public var leading: Double

        public init(family: String, source: String? = nil, fallbacks: [String] = [], class: String? = nil, weight: Int = 400,
                    style: String = "normal", textCase: String = "none", tracking: Double = 0, leading: Double = 1.4) {
            self.family = family; self.source = source; self.fallbacks = fallbacks; self.class = `class`; self.weight = weight
            self.style = style; self.textCase = textCase; self.tracking = tracking; self.leading = leading
        }

        enum CodingKeys: String, CodingKey { case family, source, fallbacks, `class`, weight, style, textCase = "case", tracking, leading }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            family = try c.decode(String.self, forKey: .family)
            source = PieceLoose.string(c, .source)
            fallbacks = PieceLoose.list(c, .fallbacks, of: String.self)
            `class` = PieceLoose.string(c, .class)
            weight = min(max(PieceLoose.int(c, .weight) ?? 400, 100), 900)
            style = PieceLoose.string(c, .style) == "italic" ? "italic" : "normal"
            textCase = PieceLoose.string(c, .textCase) ?? "none"
            tracking = min(max(PieceLoose.double(c, .tracking) ?? 0, -0.1), 0.4)
            leading = min(max(PieceLoose.double(c, .leading) ?? 1.4, 0.8), 2.2)
        }
    }

    public struct Scale: Codable, Sendable, Equatable {
        /// The body's size on a letter page, in CSS pixels.
        public var base: Double
        /// Each step up the scale is this many times the one below.
        public var ratio: Double

        public init(base: Double = 16, ratio: Double = 1.25) { self.base = base; self.ratio = ratio }

        enum CodingKeys: String, CodingKey { case base, ratio }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            base = min(max(PieceLoose.double(c, .base) ?? 16, 10), 28)
            ratio = min(max(PieceLoose.double(c, .ratio) ?? 1.25, 1.067), 1.618)
        }
    }

    public enum RoleName: String, Codable, Sendable, CaseIterable {
        case display, heading, body, caption, label, numeral
    }

    public var families: [Family]
    public var roles: [String: Role]
    public var scale: Scale

    public init(families: [Family] = [], roles: [String: Role], scale: Scale = Scale()) {
        self.families = families; self.roles = roles; self.scale = scale
    }

    enum CodingKeys: String, CodingKey { case families, roles, scale }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        families = PieceLoose.list(c, .families, of: Family.self)
        roles = (try? c.decodeIfPresent([String: PieceLoose.Element<Role>].self, forKey: .roles))?.compactMapValues(\.value) ?? [:]
        scale = (try? c.decodeIfPresent(Scale.self, forKey: .scale)) ?? Scale()
        guard roles[RoleName.body.rawValue] != nil || roles[RoleName.display.rawValue] != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "no body or display face"))
        }
    }

    /// The face a role draws in: its own, else the nearest role's (a heading the display's, a label the caption's).
    public func role(_ name: RoleName) -> Role {
        let chain: [RoleName]
        switch name {
        case .display: chain = [.display, .heading, .body]
        case .heading: chain = [.heading, .display, .body]
        case .body: chain = [.body, .heading, .display]
        case .caption: chain = [.caption, .body, .display]
        case .label: chain = [.label, .caption, .body, .display]
        case .numeral: chain = [.numeral, .display, .heading, .body]
        }
        for candidate in chain { if let role = roles[candidate.rawValue] { return role } }
        return Role(family: "Helvetica Neue", source: "system", fallbacks: ["Helvetica", "Arial", "sans-serif"], class: "sans")
    }
}
