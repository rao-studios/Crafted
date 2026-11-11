import Foundation

/// What a piece is, and what that fixes: its page in CSS pixels (the PNG is twice it), how many pages it may have, how
/// large its type runs, how many blocks a page holds, and the engine it is drawn with when the style says nothing.
public enum PieceFormat: String, Codable, Sendable, CaseIterable {
    case poster, flyer, brochure, onepager, socialcard, story, businesscard, slide, banner

    /// A format named loosely: "one-pager", "Business card", "instagram post".
    public init?(loose name: String) {
        let word = name.lowercased().filter { $0.isLetter }
        if let format = PieceFormat(rawValue: word) { self = format; return }
        switch word {
        case "onesheet", "sheet", "factsheet", "page": self = .onepager
        case "social", "post", "instagram", "instagrampost", "square", "card": self = .socialcard
        case "instagramstory", "reel", "vertical": self = .story
        case "namecard", "visitingcard", "callingcard": self = .businesscard
        case "deck", "slides", "presentation": self = .slide
        case "header", "cover", "headerimage", "leaderboard": self = .banner
        case "leaflet", "handout": self = .flyer
        case "booklet", "pamphlet", "trifold": self = .brochure
        default: return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let word = try decoder.singleValueContainer().decode(String.self)
        guard let format = PieceFormat(loose: word) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "\"\(word)\" is not a format: one of \(PieceFormat.allCases.map(\.rawValue).joined(separator: ", "))"))
        }
        self = format
    }

    /// The page, in CSS pixels.
    public var size: PieceSize {
        switch self {
        case .poster: return PieceSize(width: 1200, height: 1600)
        case .flyer, .onepager, .brochure: return PieceSize(width: 850, height: 1100)
        case .socialcard: return PieceSize(width: 1080, height: 1080)
        case .story: return PieceSize(width: 1080, height: 1920)
        case .businesscard: return PieceSize(width: 1050, height: 600)
        case .slide: return PieceSize(width: 1920, height: 1080)
        case .banner: return PieceSize(width: 1500, height: 500)
        }
    }

    /// Pages when the call names none, and the most a call may ask for.
    public var defaultPages: Int { self == .brochure ? 2 : 1 }
    public var maxPages: Int {
        switch self {
        case .brochure: return 8
        case .slide: return 12
        default: return 1
        }
    }

    /// How large type runs against a letter page's: a poster is read from across a room, a card in the hand.
    public var typeFactor: Double {
        switch self {
        case .poster: return 1.55
        case .flyer: return 1.12
        case .brochure, .onepager: return 1.0
        case .socialcard: return 1.75
        case .story: return 1.9
        case .businesscard: return 1.15
        case .slide: return 1.8
        case .banner: return 1.4
        }
    }

    /// The most blocks one page holds.
    public var blockLimit: Int {
        switch self {
        case .businesscard, .banner: return 6
        case .socialcard, .story, .slide: return 7
        case .poster: return 10
        case .flyer, .brochure: return 12
        case .onepager: return 16
        }
    }

    /// The engine when the style names none for this format.
    public var defaultArchetype: Archetype {
        switch self {
        case .poster, .socialcard, .story, .banner: return .hero
        case .flyer, .businesscard, .slide: return .split
        case .onepager, .brochure: return .column
        }
    }

    public var title: String {
        switch self {
        case .onepager: return "one-pager"
        case .socialcard: return "social card"
        case .businesscard: return "business card"
        default: return rawValue
        }
    }

    /// Wider than tall: a split goes side by side, not one above the other.
    public var isLandscape: Bool { size.width > size.height }
}
