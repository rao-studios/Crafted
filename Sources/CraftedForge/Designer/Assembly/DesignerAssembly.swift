//  WHAT: A style agent's package from the run's artefacts: the template stamped with the agent's identity, the style
//        folder (style.json, cleared faces and their licences, the mark) overlaid as it is, the proof sheet, the README,
//        the NOTICE and the designer's credit.
//  IN:   artefacts/style/**, artefacts/rights.json, artefacts/report.json, artefacts/proof-sheet.png; the request.
//  PIN:  ASSEMBLY IS PURE. Only artefacts and the request are read: no model, no question, nothing from the dropped
//        folder. A rename is a new identity over the same artefacts.

import CraftedCore
import Foundation

public enum DesignerAssembly {
    public static let styleFolder = "Sources/AtelierKit/Resources/Style"
    public static let creditFile = "Sources/AtelierAgent/Values/DesignerCredit.swift"

    public static func plan(_ request: AssemblyRequest) throws -> AssemblyPlan {
        let run = request.run
        let styleRoot = run.artefact("style")
        guard let data = try? Data(contentsOf: styleRoot.appendingPathComponent("style.json")),
              let style = try? ForgeJSON.decoder.decode(DesignerStyle.self, from: data) else {
            throw ForgeError.stage("Assemble", "the run has no reconciled style (artefacts/style/style.json): run the generation again")
        }
        let rights = run.read(RightsOutcome.self, "rights.json") ?? RightsOutcome(fonts: [], mark: nil, designer: style.credit.designer, url: style.credit.url, notes: [])
        let report = run.read(DesignerReport.self, "report.json") ?? DesignerReport()
        var verbatim: [String: Data] = [:]
        let fm = FileManager.default
        let base = styleRoot.standardizedFileURL.resolvingSymlinksInPath().path
        if let walker = fm.enumerator(at: styleRoot, includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let url as URL in walker {
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true, !url.lastPathComponent.hasPrefix(".") else { continue }
                let relative = String(url.standardizedFileURL.resolvingSymlinksInPath().path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                verbatim["\(styleFolder)/\(relative)"] = try Data(contentsOf: url)
            }
        }
        let proof = run.artefact("proof-sheet.png")
        let hasProof = report.proof && fm.fileExists(atPath: proof.path)
        if hasProof { verbatim["Assets/proof.png"] = try Data(contentsOf: proof) }
        var readmeReport = report
        readmeReport.proof = hasProof
        verbatim["README.md"] = Data(DesignerDocuments.readme(style: style, listing: request.listing, identity: request.identity, report: readmeReport).utf8)
        verbatim["NOTICE"] = Data(DesignerDocuments.notice(style: style, rights: rights, identity: request.identity, listing: request.listing).utf8)
        verbatim[creditFile] = Data(DesignerDocuments.credit(style: style).utf8)
        return AssemblyPlan(template: request.templates.folder(.designer), identity: request.identity, verbatim: verbatim)
    }

    public static func assemble(_ request: AssemblyRequest) throws -> AssembledPackage {
        let tree = try PackageAssembler.assemble(try plan(request), into: request.destination)
        let report = request.run.read(DesignerReport.self, "report.json") ?? DesignerReport()
        return AssembledPackage(tree: tree, verification: report.verification, leftOut: report.leftOut, notes: report.notes)
    }
}
