//  WHAT: The gates a style agent passes before it is offered, on the toolchain when there is one: its own tests (the
//        record found, the schema, every format drawn clean in this style), a real install on the run's shelf, its
//        `--describe` naming its word, and the proof: one call over the wire per format, the built agent drawing a
//        neutral piece from its spec with no model, every page at its exact size. The proof's PNGs become the sheet.
//  PIN:  THE PROOF IS THE AGENT'S OWN DRAWING. No in-process kit draws it: what the sheet shows is what the shipped
//        package draws on a Mac it is installed on.
//  PIN:  NO TOOLCHAIN, NO PROOF, STILL A PACKAGE. A designer's Mac without Swift gets the pre-tested template with the
//        static gates; each gate here says it was skipped, and a finding says why.

import CraftedCore
import Foundation
import ImageIO

public enum DesignerGates {
    public struct Outcome: Sendable {
        public var gates: [GateResult]
        public var report: DesignerReport
    }

    /// Each format's page, in CSS pixels: the PNG is twice it.
    static let sizes: [String: (Int, Int)] = ["poster": (1200, 1600), "flyer": (850, 1100), "brochure": (850, 1100), "onepager": (850, 1100),
                                              "socialcard": (1080, 1080), "story": (1080, 1920), "businesscard": (1050, 600),
                                              "slide": (1920, 1080), "banner": (1500, 500)]

    public static func run(_ context: ForgeContext, package: URL, identity: AgentIdentity, designer: String, leftOut: [String]) async throws -> Outcome {
        var report = DesignerReport(leftOut: leftOut)
        guard let toolchain = context.toolchain, await toolchain.version() != nil else {
            context.finding(Finding(.info, "No Swift toolchain here: the package was not tested or installed, and no proof sheet was drawn."))
            report.notes.append("Not built here: no Swift toolchain on this Mac. The template it is made from is tested as it stands.")
            return Outcome(gates: [GateResult(name: "tests", passed: false, detail: ["No Swift toolchain on this Mac."], skipped: true),
                                   GateResult(name: "proof", passed: false, detail: ["No Swift toolchain: the proof was not drawn."], skipped: true)],
                           report: report)
        }
        var gates: [GateResult] = []
        if context.options.build {
            context.progress("gates", "Running the agent's own tests", fraction: 0.05)
            do {
                let result = try await toolchain.test(package: package, filter: nil, scratch: context.run.buildScratch)
                let detail = result.succeeded ? ["\(result.passed) tests passed in \(Int(result.seconds)) s: every format drawn clean in this style."]
                    : result.failures.prefix(6).map { "\($0.test): \($0.message)" } + result.diagnostics.prefix(4).map { "\($0.file):\($0.line): \($0.message)" }
                gates.append(GateResult(name: "tests", passed: result.succeeded, detail: detail.isEmpty ? ["swift test failed."] : detail))
                if result.succeeded { report.verification.append("its own tests: \(result.passed) passed (the record, the schema, every format clean in this style)") }
            } catch {
                gates.append(GateResult(name: "tests", passed: false, detail: [error.localizedDescription]))
            }
        }
        guard context.options.install else {
            context.finding(Finding(.info, "The install gate was turned off: no proof sheet was drawn."))
            gates.append(GateResult(name: "proof", passed: false, detail: ["The install gate was turned off."], skipped: true))
            return Outcome(gates: gates, report: report)
        }
        context.progress("gates", "Installing the agent on a scratch shelf", fraction: 0.4)
        let agent: InstalledAgent
        do {
            try? FileManager.default.removeItem(at: context.run.shelf)
            agent = try await toolchain.install(package: package, shelf: context.run.shelf)
            gates.append(GateResult(name: "install", passed: true, detail: ["Installed as \(agent.name), carrying \(agent.words.joined(separator: ", "))."]))
        } catch {
            gates.append(GateResult(name: "install", passed: false, detail: [error.localizedDescription]))
            return Outcome(gates: gates, report: report)
        }
        do {
            let entries = try await toolchain.describe(agent)
            let words = ((try? JSONSerialization.jsonObject(with: entries)) as? [[String: Any]] ?? []).compactMap { $0["word"] as? String }
            let found = words.contains(identity.word)
            gates.append(GateResult(name: "describe", passed: found, detail: [found ? "--describe names \(identity.word)." : "--describe names \(words.joined(separator: ", ")), not \(identity.word)."]))
        } catch {
            gates.append(GateResult(name: "describe", passed: false, detail: [error.localizedDescription]))
        }
        // The proof: one call per format, drawn by the installed agent from a neutral spec, with no model.
        let proofFolder = context.run.root.appendingPathComponent("proof", isDirectory: true)
        try? FileManager.default.removeItem(at: proofFolder)
        var drawn: [(String, URL)] = []
        var problems: [String] = []
        for (index, format) in DesignerStyle.formats.enumerated() {
            try context.checkCancellation()
            context.progress("gates", "Drawing the proof: \(format)", fraction: 0.5 + 0.5 * Double(index) / Double(DesignerStyle.formats.count),
                             counts: ["proofs": index, "formats": DesignerStyle.formats.count])
            let outcome = try await toolchain.perform(agent, word: identity.word, input: try ProofPieces.input(format), directory: context.run.root)
            let file = proofFolder.appendingPathComponent("\(format).png")
            guard outcome.succeeded, FileManager.default.fileExists(atPath: file.path) else {
                problems.append("\(format): \(outcome.failure ?? "no file was written")")
                continue
            }
            let answer = (outcome.output.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any] ?? [:]
            let findings = answer["findings"] as? [String] ?? []
            let (w, h) = pixels(file)
            let (pw, ph) = sizes[format] ?? (0, 0)
            if w != pw * 2 || h != ph * 2 { problems.append("\(format): drawn \(w)×\(h), not \(pw * 2)×\(ph * 2).") }
            if !findings.isEmpty { problems.append("\(format): " + findings.prefix(2).joined(separator: " ")) }
            if (answer["notes"] as? [String])?.first?.contains(designer) != true {
                problems.append("\(format): the answer's notes do not credit \(designer).")
            }
            // Every page the call drew: a brochure is a PNG a page.
            let paths = (answer["paths"] as? [String] ?? [file.path]).map { URL(fileURLWithPath: $0) }
            for (page, url) in paths.enumerated() where FileManager.default.fileExists(atPath: url.path) {
                drawn.append((paths.count > 1 ? "\(format) \(page + 1)" : format, url))
            }
            if w == pw * 2, h == ph * 2, findings.isEmpty {
                report.verification.append("\(format): drawn clean by the installed agent (\(w)×\(h))")
            }
        }
        gates.append(GateResult(name: "proof", passed: problems.isEmpty,
                                detail: problems.isEmpty ? ["Every format drawn clean by the installed agent, from its spec, with no model."] : problems))
        if let sheet = ProofSheet.compose(drawn.map { (name: $0.0, url: $0.1) }) {
            try AtomicFile.write(sheet, to: context.run.artefact("proof-sheet.png"))
            report.proof = true
        }
        for (_, file) in drawn {
            if let data = try? Data(contentsOf: file) { try? AtomicFile.write(data, to: context.run.artefact("proof/\(file.lastPathComponent)")) }
        }
        return Outcome(gates: gates, report: report)
    }

    static func pixels(_ url: URL) -> (Int, Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return (0, 0) }
        return ((properties[kCGImagePropertyPixelWidth] as? Int) ?? 0, (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0)
    }
}
