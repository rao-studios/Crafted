//  WHAT: The live toolchain: `swift build` and `swift test` with a scratch path, their diagnostics and results
//        parsed, and Granite's installer and process client for the install gate (install, --describe, one perform
//        over the wire with no host model). See SwiftToolchain+Agents for the last three.
//  IN:   The Xcode or Command Line Tools toolchain, through /usr/bin/xcrun.
//  OUT:  ForgeService and crafted-check give it to the Forge; the engineer port loop builds and tests through it.
//  PIN:  NO TOOLCHAIN IS AN ANSWER, NOT A CRASH. `version()` is nil when `xcrun swift --version` does not run, and
//        the forge then skips its build gates ("not built here").
//  PIN:  EVERY RUN ENDS. Each call has a deadline and ends its process group when the task is cancelled.

import CraftedForge
import Foundation

public struct SwiftToolchain: ForgeToolchain {
    public static let xcrun = "/usr/bin/xcrun"

    public var buildTimeout: TimeInterval
    public var testTimeout: TimeInterval
    public var installTimeout: TimeInterval
    public var callTimeout: TimeInterval
    /// SwiftPM's `--build-system`. Native by default: it runs every compile job, so a build says every error in a
    /// file, where the newer build system stops at the first job that fails (one error at a time for the port loop).
    /// A toolchain that no longer knows the flag is asked again without it.
    public var buildSystem: String?
    private let found = VersionBox()

    public init(buildTimeout: TimeInterval = 1800, testTimeout: TimeInterval = 1800, installTimeout: TimeInterval = 1800,
                callTimeout: TimeInterval = 300, buildSystem: String? = "native") {
        self.buildTimeout = buildTimeout
        self.testTimeout = testTimeout
        self.installTimeout = installTimeout
        self.callTimeout = callTimeout
        self.buildSystem = buildSystem
    }

    // MARK: Version

    /// "Swift 6.4.2", or nil when there is no toolchain (`unavailableReason()` says why). Asked once.
    public func version() async -> String? {
        await lookUp().version
    }

    /// Why there is no toolchain, or nil when there is one.
    public func unavailableReason() async -> String? {
        await lookUp().reason
    }

    private func lookUp() async -> (version: String?, reason: String?) {
        if let known = found.value { return known }
        let answer: (String?, String?)
        do {
            let output = try await ToolProcess.run([Self.xcrun, "swift", "--version"],
                                                   in: FileManager.default.temporaryDirectory, timeout: 60)
            if output.status == 0, let version = Self.version(in: output.combined) {
                answer = (version, nil)
            } else {
                let said = output.combined.split(separator: "\n").first.map(String.init) ?? "exit \(output.status)"
                answer = (nil, "`xcrun swift --version` said: \(said)")
            }
        } catch {
            answer = (nil, "\(error)")
        }
        found.value = answer
        return answer
    }

    /// "Apple Swift version 6.4.2 (swiftlang-…)" → "Swift 6.4.2".
    static func version(in text: String) -> String? {
        guard let range = text.range(of: #"Swift version (\d+(?:\.\d+)*)"#, options: .regularExpression) else { return nil }
        let number = text[range].split(separator: " ").last.map(String.init) ?? ""
        return "Swift " + number
    }

    // MARK: Build

    public func build(package: URL, target: String?, scratch: URL) async throws -> BuildResult {
        var arguments = [Self.xcrun, "swift", "build", "--package-path", package.path, "--scratch-path", scratch.path]
        if let target { arguments += ["--target", target] }
        arguments += ["-Xswiftc", "-diagnostic-style=llvm"]
        let output = try await swift(arguments, in: package, timeout: buildTimeout)
        let failed = output.status != 0 || output.timedOut
        var diagnostics = DiagnosticParser.parse(output.combined, package: package, failed: failed)
        if output.timedOut { diagnostics.append(Self.timeout("swift build", buildTimeout)) }
        return BuildResult(succeeded: !failed, diagnostics: diagnostics, log: Self.tail(output.combined), seconds: output.seconds)
    }

    // MARK: Test

    public func test(package: URL, filter: String?, scratch: URL) async throws -> TestResult {
        let report = scratch.appendingPathComponent("xunit-\(UUID().uuidString).xml")
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { Self.removeReports(beside: report) }
        var arguments = [Self.xcrun, "swift", "test", "--package-path", package.path, "--scratch-path", scratch.path]
        if let filter { arguments += ["--filter", filter] }
        arguments += ["--xunit-output", report.path, "-Xswiftc", "-diagnostic-style=llvm"]
        let output = try await swift(arguments, in: package, timeout: testTimeout)
        let log = Self.tail(output.combined)
        var counts = TestOutputParser.parse(output.combined)
        if counts.passed == 0, counts.failures.isEmpty, let summary = Self.readReports(beside: report) {
            counts.ran = true
            counts.passed = summary.tests - summary.failures
            if summary.failures > 0 { counts.failures = [TestResult.Failure(test: "tests", message: "\(summary.failures) failed")] }
        }
        guard counts.ran else {
            // The tests did not build (or never started): the build's diagnostics say why.
            var diagnostics = DiagnosticParser.parse(output.combined, package: package, failed: true)
            if output.timedOut { diagnostics.append(Self.timeout("swift test", testTimeout)) }
            return TestResult(succeeded: false, diagnostics: diagnostics, log: log, seconds: output.seconds)
        }
        var failures = counts.failures
        if output.timedOut { failures.append(TestResult.Failure(test: "run", message: "swift test did not finish in \(Int(testTimeout)) s.")) }
        let succeeded = output.status == 0 && failures.isEmpty && !output.timedOut
        if !succeeded, failures.isEmpty {
            failures.append(TestResult.Failure(test: "run", message: "swift test exited with status \(output.status)."))
        }
        return TestResult(succeeded: succeeded, passed: counts.passed, failures: failures, log: log, seconds: output.seconds)
    }

    // MARK: Running

    /// `xcrun swift <subcommand> …` with the chosen build system; once more without it when the toolchain refuses it.
    func swift(_ arguments: [String], in folder: URL, timeout: TimeInterval) async throws -> ToolProcess.Output {
        guard let buildSystem else { return try await run(arguments, in: folder, timeout: timeout) }
        var chosen = arguments
        chosen.insert(contentsOf: ["--build-system", buildSystem], at: 3)
        let output = try await run(chosen, in: folder, timeout: timeout)
        let refused = output.status != 0 && output.combined.contains("build-system")
            && (output.combined.contains("Unknown option") || output.combined.contains("invalid value") || output.combined.contains("is not a valid"))
        return refused ? try await run(arguments, in: folder, timeout: timeout) : output
    }

    func run(_ arguments: [String], in folder: URL, timeout: TimeInterval) async throws -> ToolProcess.Output {
        do {
            return try await ToolProcess.run(arguments, in: folder, timeout: timeout)
        } catch let failure as ToolProcess.SpawnFailure {
            throw ForgeError.noToolchain(failure.description)
        }
    }

    static func timeout(_ what: String, _ seconds: TimeInterval) -> Diagnostic {
        Diagnostic(file: "", line: 0, column: 0, severity: .error, message: "\(what) did not finish in \(Int(seconds)) s and was stopped.")
    }

    /// The last 64 KB of a log: what a person or a repair prompt reads.
    static func tail(_ text: String, limit: Int = 65_536) -> String {
        text.utf8.count <= limit ? text : "…\n" + String(decoding: Array(text.utf8.suffix(limit)), as: UTF8.self)
    }

    /// The xUnit report and its Swift Testing sibling (`<name>-swift-testing.xml`), summed.
    static func readReports(beside report: URL) -> (tests: Int, failures: Int)? {
        let sibling = report.deletingPathExtension().path + "-swift-testing.xml"
        var total: (tests: Int, failures: Int)?
        for path in [report.path, sibling] {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8), let counts = TestOutputParser.xunit(text) else { continue }
            total = ((total?.tests ?? 0) + counts.tests, (total?.failures ?? 0) + counts.failures)
        }
        return total
    }

    static func removeReports(beside report: URL) {
        try? FileManager.default.removeItem(at: report)
        try? FileManager.default.removeItem(atPath: report.deletingPathExtension().path + "-swift-testing.xml")
    }
}
