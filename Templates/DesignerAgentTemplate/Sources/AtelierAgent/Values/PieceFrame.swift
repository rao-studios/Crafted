import AtelierKit
import Foundation

/// What a run streams while it works: the piece drafted, each round measured and revised, and the piece written.
public enum PieceFrame: Sendable {
    case drafted(Piece)
    case measured(round: Int, findings: [PieceFinding])
    case revised(round: Int)
    case written(PieceResult)

    /// The answer, when this frame carries it.
    public var result: PieceResult? {
        if case .written(let result) = self { return result }
        return nil
    }
}
