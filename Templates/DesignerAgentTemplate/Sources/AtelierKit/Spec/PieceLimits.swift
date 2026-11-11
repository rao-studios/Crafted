import Foundation

/// What a block holds before it is too much for any page: characters per text, lines per list, rows per table. The
/// kit draws past a limit clamped, and tells the model, so the words get fixed and the piece still draws.
public enum PieceLimits {
    /// The most characters a block's main text holds.
    public static func text(_ kind: PieceBlock.Kind) -> Int {
        switch kind {
        case .headline: return 72
        case .kicker: return 48
        case .subhead: return 140
        case .lead: return 320
        case .body: return 900
        case .stat: return 90
        case .quote: return 240
        case .callout: return 300
        case .image: return 120
        case .cta: return 80
        case .logo: return 40
        case .footer: return 220
        case .list, .steps, .details, .table, .divider: return 120
        }
    }

    public static let title = 64
    public static let item = 110
    public static let figure = 10
    public static let label = 36
    public static let by = 60
    public static let cell = 48
    public static let rows = 10
    public static let columns = 5

    public static func items(_ kind: PieceBlock.Kind) -> Int {
        switch kind {
        case .steps: return 7
        case .details: return 8
        default: return 8
        }
    }
}
