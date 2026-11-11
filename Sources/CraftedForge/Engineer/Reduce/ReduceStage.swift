//  WHAT: The cards reduced to what the project is: its modules (code), its domain and nature, its use cases, each
//        judged portable or not (code), and the top use cases verified against only the lines they cite.
//  IN:   The brief, the cards, the import graph, the inventory.
//  OUT:  modules.json, domain.json, usecases.json (verified marked); a progress count of use cases.
//  PIN:  ONLY VERIFIED USE CASES FEED THE INTERPRETATIONS. A use case the coder cannot confirm from its own cited lines,
//        cut verbatim, is kept for the record and offered nowhere.

import Foundation

struct ReduceStage {
    let context: ForgeContext
    let inventory: Inventory
    /// How many use cases get the second look.
    static let verifyLimit = 6

    var ask: EngineerAsk { EngineerAsk(context: context) }

    func domain(brief: ProjectBrief, cards: [FileCard], modules: ModuleMap) async throws -> DomainModel {
        let user = brief.prefix + "\n\nModules:\n" + modules.digest + "\n\nCards:\n" + cards.map(\.digest).joined(separator: "\n")
        return try await ask.object(.domain, user, as: DomainModel.self, budget: .reduce)
    }

    func usecases(brief: ProjectBrief, domain: DomainModel, cards: [FileCard]) async throws -> [UseCase] {
        let user = brief.prefix + "\n\n" + domain.digest + "\n\nCards:\n" + cards.map(\.digest).joined(separator: "\n")
            + "\n\nTests in the project: " + inventory.with(.test).map(\.path).joined(separator: ", ")
        let list = try await ask.object(.usecases, user, as: UseCaseList.self, budget: .reduce) { list in
            problems(list.usecases)
        }
        return list.usecases.map { usecase in
            var usecase = usecase
            usecase.portability = Portability.judge(usecase)
            return usecase
        }
    }

    /// Ids unique; every citation a file of the inventory with lines it has.
    func problems(_ usecases: [UseCase]) -> [String] {
        var problems: [String] = []
        if usecases.isEmpty { problems.append("there are no use cases: name at least one chain from a trigger to an output") }
        var seen: Swift.Set<String> = []
        for usecase in usecases {
            if !seen.insert(usecase.id).inserted { problems.append("the id \(usecase.id) is used twice") }
            for evidence in usecase.evidence {
                guard let file = inventory.file(evidence.path), file.verdict.isOpened else {
                    problems.append("\(usecase.id) cites \(evidence.path), which is not a file of the project that was read"); continue
                }
                if let range = evidence.range, range.start < 1 || range.end > file.lines {
                    problems.append("\(usecase.id) cites \(evidence.text), but \(evidence.path) has \(file.lines) lines")
                }
            }
        }
        return problems
    }

    /// The top portable use cases, checked against only their cited lines; the rest kept unverified.
    func verify(_ usecases: [UseCase], brief: ProjectBrief) async throws -> [UseCase] {
        let ranked = usecases.indices.filter { usecases[$0].portability?.verdict != "not-portable" }
            .sorted { usecases[$0].value * usecases[$0].confidence > usecases[$1].value * usecases[$1].confidence }
            .prefix(Self.verifyLimit)
        var result = usecases
        for (count, index) in ranked.enumerated() {
            try context.checkCancellation()
            let usecase = usecases[index]
            context.progress("reduce", "Checking \"\(usecase.title)\" against its lines", fraction: Double(count) / Double(max(ranked.count, 1)),
                             counts: ["useCases": usecases.count])
            let cited = usecase.evidence.compactMap { evidence -> String? in
                let lines = inventory.lines(evidence.path)
                let range = evidence.range ?? LineRange(1, lines.count)
                guard SourceText.cut(lines, range) != nil else { return nil }
                return "--- \(evidence.text)\n" + SourceText.numbered(lines, from: range.start, through: range.end)
            }
            guard !cited.isEmpty else { continue }
            let user = brief.prefix + "\n\nThe use case:\n" + usecase.digest + "\nSteps:\n"
                + usecase.steps.map { "- \($0.text)" }.joined(separator: "\n") + "\n\nThe lines it cites, verbatim:\n" + cited.joined(separator: "\n\n")
            let verdict = try await ask.object(.verify, user, as: VerifyVerdict.self, budget: .card) { verdict in
                verdict.id == usecase.id ? [] : ["id is \(verdict.id), and the use case checked is \(usecase.id)"]
            }
            result[index].verified = verdict.confirmed
            if verdict.confirmed {
                if let title = verdict.title, !title.isEmpty { result[index].title = title }
                if let rules = verdict.rules, !rules.isEmpty { result[index].rules = rules }
            }
        }
        return result
    }
}
