import AtelierKit
import Foundation
import GraniteAgents

/// What a call answers (granite-answer/1): the files written (a PNG, a PNG a page, or a paged PDF, each carrying the
/// spec it was drawn from and the designer's credit), the size, the engines, the rounds it took, what the last round
/// still found, and whose style it is.
public struct PieceResult: AgentAnswer, Equatable {
    /// The first file written.
    public var path: String?
    public var paths: [String]
    /// What it is: poster, flyer, brochure, onepager, socialcard, story, businesscard, slide, banner. (`format` is the
    /// answer standard's own key.)
    public var piece: String
    /// In pixels: twice the page's CSS size. A PDF's pages are the page's own size in points.
    public var width: Int
    public var height: Int
    public var pages: Int
    public var archetypes: [String]
    public var theme: String
    public var rounds: Int
    /// What the piece written still has wrong, one sentence each; empty when it measured clean.
    public var findings: [String]
    public var title: String
    public var style: String
    public var designer: String
    /// Whether the piece carries its colophon.
    public var colophon: Bool
    public var notes: [String]
    public var made: [AgentMade]
    public var expected: [AgentExpected]
    public var problems: [AgentProblem]

    public init(path: String?, paths: [String], piece: String, width: Int, height: Int, pages: Int, archetypes: [String], theme: String,
                rounds: Int, findings: [String], title: String, style: String, designer: String, colophon: Bool,
                notes: [String], made: [AgentMade], expected: [AgentExpected], problems: [AgentProblem]) {
        self.path = path; self.paths = paths; self.piece = piece; self.width = width; self.height = height; self.pages = pages
        self.archetypes = archetypes; self.theme = theme; self.rounds = rounds; self.findings = findings; self.title = title
        self.style = style; self.designer = designer; self.colophon = colophon; self.notes = notes; self.made = made
        self.expected = expected; self.problems = problems
    }
}
