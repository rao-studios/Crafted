//  WHAT: What a failed build or test says, trimmed to what a repair needs: the candidate's own errors first, located
//        and with the offending line, at most six; then other files' errors; a test's failures by their vector or fact.
//  PIN:  SMALL ON PURPOSE. A repair prompt with a page of compiler output repairs worse than one with the first error.

import Foundation

enum DiagnosticTrim {
    static func build(_ result: BuildResult, candidate: String, text: String) -> AttemptFailure {
        let lines = SourceText.lines(text)
        let name = (candidate as NSString).lastPathComponent
        let errors = result.errors
        let own = errors.filter { ($0.file as NSString).lastPathComponent == name }
        let chosen = (own.isEmpty ? errors : own).prefix(6)
        var said = chosen.map { diagnostic -> String in
            var line = "\((diagnostic.file as NSString).lastPathComponent):\(diagnostic.line): \(diagnostic.message)"
            if (diagnostic.file as NSString).lastPathComponent == name, diagnostic.line >= 1, diagnostic.line <= lines.count {
                line += " — `" + lines[diagnostic.line - 1].trimmingCharacters(in: .whitespaces) + "`"
            }
            return line
        }
        if said.isEmpty {
            said = SourceText.lines(result.log).filter { $0.contains("error") }.prefix(6).map { String($0.prefix(300)) }
        }
        if said.isEmpty { said = ["the build failed and said nothing located"] }
        let keys = chosen.isEmpty ? said : chosen.map(\.fingerprint)
        return AttemptFailure(rung: "build", lines: said, hint: RepairHints.hint(for: said), keys: keys)
    }

    static func test(_ result: TestResult, candidate: String, text: String) -> AttemptFailure {
        if !result.diagnostics.filter({ $0.severity == .error }).isEmpty {
            var failure = build(BuildResult(succeeded: false, diagnostics: result.diagnostics, log: result.log), candidate: candidate, text: text)
            failure.rung = "test build"
            return failure
        }
        var said = result.failures.prefix(8).map { failure in
            let message = failure.message.replacingOccurrences(of: "XCTAssertEqual failed: ", with: "")
            return String(message.prefix(400))
        }
        if said.isEmpty {
            said = SourceText.lines(result.log).filter { $0.contains("error") || $0.contains("failed") }.prefix(6).map { String($0.prefix(300)) }
        }
        if said.isEmpty { said = ["the tests did not pass and said nothing located"] }
        return AttemptFailure(rung: "test", lines: said, hint: RepairHints.hint(for: said), keys: result.failures.prefix(8).map { "\($0.test)|\($0.message)" })
    }
}
