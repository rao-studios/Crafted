//  WHAT: The rights stage: what only the person can say. Which of the folder's fonts may ship (open by their own
//        licence, attested by the designer, or stood in for by an open or system face), which file is the designer's
//        own mark, and who every piece credits.
//  IN:   The font facts, the mark files, the looks (a client's logo seen on a piece), the options' credit.
//  OUT:  artefacts/rights.json; reconcile (bundled faces, the mark, the credit), NOTICE.
//  PIN:  CONSERVATIVE DEFAULTS. A face ships by default only when its own name table or a licence file beside it says
//        it is open; a mark ships by default only when its file is named as the designer's (mark, monogram,
//        signature), never a "logo" that may be a client's, and never one a look saw as a client's.

import CraftedCore
import Foundation

public struct RightsOutcome: Codable, Sendable, Equatable {
    public struct Font: Codable, Sendable, Equatable {
        public var family: String
        /// open, attest, substitute.
        public var decision: String
        public var licence: String?
        /// The face files, relative to the dropped folder.
        public var files: [String]
        public var licenceFile: String?
    }

    public var fonts: [Font]
    /// The designer's mark, relative to the dropped folder.
    public var mark: String?
    public var designer: String
    public var url: String?
    /// What was decided and why, one sentence each, for the style's provenance.
    public var notes: [String]

    public var cleared: [Font] { fonts.filter { $0.decision != "substitute" } }
}

public enum DesignRights {
    /// One decision per family the folder's font files hold.
    public static func fontDecisions(_ facts: [FontFact]) -> [(decision: Decision, family: String)] {
        let families = Dictionary(grouping: facts, by: \.family)
        return families.keys.sorted().map { family in
            let faces = families[family]!
            let open = faces.compactMap(\.openLicence).first
            var options: [Decision.Option] = []
            if let open { options.append(.init(id: "open", title: "Ship it", detail: "Its licence is open (\(open)).")) }
            options.append(.init(id: "attest", title: "Ship it: I may publish this font", detail: "You hold the right to publish it with the agent."))
            options.append(.init(id: "substitute", title: "Use a stand-in", detail: "An open or system face of the same class stands in; the family is still named."))
            let detail = [faces.first?.licenceText.map { "Its name table says: \($0.prefix(160))" }, faces.first?.licenceFile.map { "Licence file: \($0)" },
                          "Files: " + Set(faces.map(\.path)).sorted().joined(separator: ", ")].compactMap { $0 }
            return (Decision(id: "font-" + slug(family), kind: .fontRights, question: "May \(family) ship inside the agent?", detail: detail,
                             options: options, defaultOption: open != nil ? "open" : "substitute"), family)
        }
    }

    /// The mark question, when the folder holds files named as marks. A file a look saw as a client's is not offered.
    public static func markDecision(_ marks: [String], looks: [Observation]) -> Decision? {
        let clientWords = looks.flatMap(\.marks).filter { $0.what == "client-logo" }.compactMap(\.text)
            .flatMap { $0.lowercased().split { !$0.isLetter }.map(String.init) }.filter { $0.count >= 3 }
        let offered = marks.filter { path in
            let name = (path as NSString).lastPathComponent.lowercased()
            return !clientWords.contains(where: name.contains) && !name.contains("client")
        }
        guard !offered.isEmpty else { return nil }
        let own = offered.first { path in
            let name = (path as NSString).lastPathComponent.lowercased()
            return ["mark", "monogram", "signature", "emblem"].contains(where: name.contains) && !name.contains("logo")
        }
        let options = offered.map { Decision.Option(id: $0, title: ($0 as NSString).lastPathComponent, detail: "Carry it on every piece, in its corner.") }
            + [Decision.Option(id: "none", title: "No mark", detail: "Pieces carry only the colophon.")]
        return Decision(id: "mark", kind: .markChoice, question: "Which of these is your own mark?",
                        detail: ["A client's logo never ships, and neither does a sample piece."], options: options, defaultOption: own ?? "none")
    }

    /// Who every piece credits: the name in Settings, else the one the folder declares (an about.txt's "Designed by").
    public static func creditDecision(options: ForgeOptions, declared: DesignMeasures.Credit?) -> Decision {
        let name = DesignerText.nonBlank(options.credit) ?? declared?.name ?? "the designer"
        return Decision(id: "credit", kind: .designerCredit, question: "Every piece will credit \(name). Is that the name to show?",
                        detail: ["The credit is on the listing, the README, the NOTICE, every answer and a colophon on every piece."],
                        options: [.init(id: "use", title: "Credit \(name)"), .init(id: "other", title: "Another name", detail: "Type it.")],
                        defaultOption: "use", takesText: true)
    }

    /// The stage: ask each question (or take its default) and write what was decided.
    public static func run(_ context: ForgeContext, inventory: DesignInventory, measures: DesignMeasures, looks: [Observation]) async throws -> RightsOutcome {
        var fonts: [RightsOutcome.Font] = []
        var notes: [String] = []
        for (decision, family) in fontDecisions(measures.fonts) {
            try context.checkCancellation()
            let answer = try await context.decide(decision)
            let faces = measures.fonts.filter { $0.family == family }
            let chosen = decision.options.contains { $0.id == answer.option } ? answer.option : decision.defaultOption
            fonts.append(.init(family: family, decision: chosen, licence: chosen == "attest" ? "attested" : faces.compactMap(\.openLicence).first,
                               files: Array(Set(faces.map(\.path))).sorted(), licenceFile: faces.compactMap(\.licenceFile).first))
            notes.append(chosen == "substitute" ? "\(family) is named but does not ship: a stand-in of its class draws it."
                         : "\(family) ships (\(chosen == "open" ? "its licence is open" : "the designer attested they may publish it")).")
            if chosen == "substitute" {
                context.finding(Finding(.rights, "\(family) will not ship; a face of its class stands in.", path: faces.first?.path))
            }
        }
        var mark: String?
        if let decision = markDecision(inventory.marks, looks: looks) {
            let answer = try await context.decide(decision)
            mark = answer.option == "none" || !inventory.marks.contains(answer.option) ? nil : answer.option
            if let mark { notes.append("The designer's mark is \((mark as NSString).lastPathComponent).") }
        }
        for look in looks { for seen in look.marks where seen.what == "client-logo" {
            let text = seen.text.map { " (\($0))" } ?? ""
            notes.append("A client's logo\(text) was seen on a piece and is not carried.")
            context.finding(Finding(.rights, "A client's logo\(text) was seen on a piece; it never ships."))
        } }
        let credit = creditDecision(options: context.options, declared: measures.credit)
        let answer = try await context.decide(credit)
        let named = answer.option == "other" ? DesignerText.nonBlank(answer.text) : nil
        let designer = named ?? DesignerText.nonBlank(context.options.credit) ?? measures.credit?.name ?? "the designer"
        let url = DesignerText.nonBlank(context.options.creditURL) ?? (designer == measures.credit?.name ? measures.credit?.url : nil)
        return RightsOutcome(fonts: fonts, mark: mark, designer: designer, url: url, notes: notes)
    }

    static func slug(_ text: String) -> String {
        text.lowercased().split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: "-")
    }
}

/// Small text helpers of the designer pipeline's own, kept in a namespace so no other track's extension can clash.
enum DesignerText {
    /// The text trimmed, or nil when it is only spaces.
    static func nonBlank(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
