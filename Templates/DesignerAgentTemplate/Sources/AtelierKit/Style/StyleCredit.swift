import Foundation

/// Who the style belongs to, and how a piece credits them: the colophon on every piece unless the caller turns it off,
/// or always when the designer requires it.
public struct StyleCredit: Codable, Sendable, Equatable {
    public enum Colophon: String, Codable, Sendable, CaseIterable {
        /// On unless a call says `credit: false`.
        case defaultOn = "default-on"
        /// On, whatever a call says.
        case required
        /// Off unless a call says `credit: true`.
        case off
    }

    public var designer: String
    public var url: String?
    /// The designer's own words for the colophon, after their name and the style's.
    public var line: String?
    public var colophon: Colophon
    /// The style's own licence: CC-BY-4.0 unless the designer chose another.
    public var styleLicence: String

    public init(designer: String, url: String? = nil, line: String? = nil, colophon: Colophon = .defaultOn, styleLicence: String = "CC-BY-4.0") {
        self.designer = designer; self.url = url; self.line = line; self.colophon = colophon; self.styleLicence = styleLicence
    }

    enum CodingKeys: String, CodingKey { case designer, url, line, colophon, styleLicence }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        designer = PieceLoose.string(c, .designer)?.nonEmptyText ?? "the designer"
        url = PieceLoose.string(c, .url)?.nonEmptyText
        line = PieceLoose.string(c, .line)?.nonEmptyText
        colophon = PieceLoose.string(c, .colophon).flatMap(Colophon.init(rawValue:)) ?? .defaultOn
        styleLicence = PieceLoose.string(c, .styleLicence)?.nonEmptyText ?? "CC-BY-4.0"
    }

    /// Whether a piece carries the colophon, given what the call asked (`credit`, nil when it said nothing).
    public func shows(asked: Bool?) -> Bool {
        switch colophon {
        case .required: return true
        case .defaultOn: return asked ?? true
        case .off: return asked ?? false
        }
    }
}
