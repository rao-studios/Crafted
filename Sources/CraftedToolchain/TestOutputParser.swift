//  WHAT: What `swift test` said: how many tests passed, which failed and why, for XCTest and Swift Testing alike,
//        with the xUnit report as the count of last resort.
//  IN:   The test run's output; the --xunit-output file(s), when written.
//  OUT:  SwiftToolchain.test.
//
//        XCTest         Test Case '-[ModCoreTests.TaxTests testRounds]' passed (0.001 seconds).
//                       /p/Tests/ModCoreTests/TaxTests.swift:12: error: -[ModCoreTests.TaxTests testRounds] : XCTAssertEqual failed: …
//        Swift Testing  ✔ Test rounds() passed after 0.001 seconds.
//                       ✘ Test rounds() recorded an issue at TaxTests.swift:12:5: Expectation failed: …
//                       ✘ Test rounds() failed after 0.002 seconds with 1 issue.

import CraftedForge
import Foundation

enum TestOutputParser {
    struct Counts: Equatable {
        var passed = 0
        var failures: [TestResult.Failure] = []
        /// Whether any test said it started, passed or failed: the tests built and ran.
        var ran = false
    }

    static let xcPassed = regex(#"^Test Case '-\[(\S+) (\S+)\]' passed"#)
    static let xcFailed = regex(#"^Test Case '-\[(\S+) (\S+)\]' failed"#)
    static let xcIssue = regex(#"^.+?:\d+: error: -\[(\S+) (\S+)\] : (.*)$"#)
    // Swift Testing starts each line with a symbol (an SF Symbol in Terminal, ✔ ✘ ◇ elsewhere) and spaces.
    static let stPassed = regex(#"^\S+\s+Test (.+?) passed after"#)
    static let stFailed = regex(#"^\S+\s+Test (.+?) failed after"#)
    static let stIssue = regex(#"^\S+\s+Test (.+?) recorded an issue at \S+?: (.*)$"#)
    static let ranMarker = regex(#"^(?:Test Suite '|Test Case '|\S+\s+Test run with |\S+\s+Test \S)"#)

    static func parse(_ output: String) -> Counts {
        var counts = Counts()
        var messages: [String: String] = [:]
        var failedOrder: [String] = []
        func failed(_ test: String) { if !failedOrder.contains(test) { failedOrder.append(test) } }

        for raw in DiagnosticParser.stripANSI(output).split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            if first(ranMarker, line) != nil { counts.ran = true }
            if first(xcPassed, line) != nil {
                counts.passed += 1
            } else if let groups = first(xcFailed, line) {
                failed(xcName(groups[0], groups[1]))
            } else if let groups = first(xcIssue, line) {
                let test = xcName(groups[0], groups[1])
                if messages[test] == nil { messages[test] = groups[2] }
                failed(test)
            } else if let groups = first(stIssue, line) {
                if messages[groups[0]] == nil { messages[groups[0]] = groups[1] }
                failed(groups[0])
            } else if first(stPassed, line) != nil, !line.contains("Test run with") {
                counts.passed += 1
            } else if let groups = first(stFailed, line), !line.contains("Test run with") {
                failed(groups[0])
            }
        }
        counts.failures = failedOrder.map { TestResult.Failure(test: $0, message: messages[$0] ?? "failed") }
        return counts
    }

    /// Tests and failures from an xUnit report: `<testsuite … failures="1" … tests="4">`, summed.
    static func xunit(_ text: String) -> (tests: Int, failures: Int)? {
        let suite = regex(#"<testsuite\b[^>]*>"#)
        var tests = 0, failures = 0, any = false
        let ns = text as NSString
        for match in suite.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: match.range)
            guard let count = attribute("tests", tag) else { continue }
            any = true
            tests += count
            failures += (attribute("failures", tag) ?? 0) + (attribute("errors", tag) ?? 0)
        }
        return any ? (tests, failures) : nil
    }

    static func xcName(_ type: String, _ method: String) -> String {
        "\(type.split(separator: ".").last.map(String.init) ?? type).\(method)"
    }

    static func attribute(_ name: String, _ tag: String) -> Int? {
        guard let range = tag.range(of: #"\b\#(name)="(\d+)""#, options: .regularExpression) else { return nil }
        return Int(tag[range].filter(\.isNumber))
    }

    static func regex(_ pattern: String) -> NSRegularExpression { try! NSRegularExpression(pattern: pattern) }

    /// The capture groups of the first match in `line`, or nil.
    static func first(_ regex: NSRegularExpression, _ line: String) -> [String]? {
        let ns = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<max(match.numberOfRanges, 1)).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }
}
