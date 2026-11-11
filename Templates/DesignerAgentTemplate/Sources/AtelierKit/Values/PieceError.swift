import Foundation

/// What a call can say besides a piece.
public enum PieceError: Error, Equatable, CustomStringConvertible {
    /// No spec was given and the host offers no model to write one.
    case noModel(String)
    /// The spec could not be read as a piece.
    case spec(String)
    /// The model's draft was not a piece: no blocks.
    case empty(String)
    /// style.json could not be read.
    case style(String)
    /// The style's resources were not found where the package's bundle should be.
    case resources(tried: [String])
    /// WebKit did not load, measure or export the piece.
    case render(String)
    /// A file could not be written.
    case unwritable(String)
    /// The call asked for something the kit cannot draw: an unknown size, too many pages.
    case call(String)

    public var description: String {
        switch self {
        case .noModel(let word):
            return "\(word) writes a piece with the host's model, and this host has none: give it a `spec` (a piece's PNG, PDF or JSON) to draw again, or call it from an app with a model loaded"
        case .spec(let reason): return "the spec could not be read as a piece: \(reason)"
        case .empty(let reason): return "the model's draft is not a piece: \(reason)"
        case .style(let reason): return "the style could not be read: \(reason)"
        case .resources(let tried): return "the style's resources were not found; looked in " + tried.joined(separator: ", ")
        case .render(let reason): return "WebKit could not draw the piece: \(reason)"
        case .unwritable(let path): return "could not write \(path)"
        case .call(let reason): return reason
        }
    }
}
