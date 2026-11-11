import Foundation

/// Which of the style's two themes a piece draws in. Left out, the designer's own ground.
public enum PieceTheme: String, Codable, Sendable, CaseIterable {
    case light
    case dark

    public init(from decoder: Decoder) throws {
        let word = ((try? decoder.singleValueContainer().decode(String.self)) ?? "").lowercased()
        self = word.contains("dark") || word == "night" ? .dark : .light
    }
}
