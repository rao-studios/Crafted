//  WHAT: A question a run cannot answer itself, and the person's answer: which fonts may ship, which picture is the
//        designer's own mark, a unit that could not be ported, a source licence, secrets found.
//  OUT:  The Generation page's question card; crafted-check answers with each default.

import Foundation

public struct Decision: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case fontRights, markChoice, designerCredit, sourceLicence, secretsFound, unitParked, nameInvalid, nothingPortable
    }

    public struct Option: Codable, Sendable, Equatable, Identifiable, Hashable {
        public var id: String
        public var title: String
        public var detail: String?

        public init(id: String, title: String, detail: String? = nil) {
            self.id = id; self.title = title; self.detail = detail
        }
    }

    public var id: String
    public var kind: Kind
    public var question: String
    public var detail: [String]
    public var options: [Option]
    public var defaultOption: String
    /// Whether the person may add words (a credit name, a steer).
    public var takesText: Bool

    public init(id: String, kind: Kind, question: String, detail: [String] = [], options: [Option],
                defaultOption: String, takesText: Bool = false) {
        self.id = id; self.kind = kind; self.question = question; self.detail = detail; self.options = options
        self.defaultOption = defaultOption; self.takesText = takesText
    }
}

public struct DecisionAnswer: Codable, Sendable, Equatable {
    public var option: String
    public var text: String?

    public init(option: String, text: String? = nil) {
        self.option = option
        self.text = text
    }
}

/// The person's answer to three interpretations: one of them, or none with a steer in their words.
public enum InterpretationChoice: Codable, Sendable, Equatable {
    case pick(Int)
    case steer(String)
}
