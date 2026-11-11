//  WHAT: The toolchain seam: build and test a package, install it as Craft would, ask it what it carries, and make
//        one call over the wire. The live side is CraftedToolchain (`swift build`, Granite's AgentInstaller).
//  PIN:  OPTIONAL. A designer's Mac may have no Swift toolchain; the forge then ships the pre-tested template with
//        the static gates only, and the report says "not built here".

import Foundation

public struct Diagnostic: Codable, Sendable, Equatable, Hashable {
    public enum Severity: String, Codable, Sendable { case error, warning, note }

    public var file: String
    public var line: Int
    public var column: Int
    public var severity: Severity
    public var message: String

    public init(file: String, line: Int, column: Int, severity: Severity, message: String) {
        self.file = file; self.line = line; self.column = column; self.severity = severity; self.message = message
    }

    /// The same failure, whatever line it moved to: what the port loop compares to see whether a strategy helps.
    public var fingerprint: String { "\((file as NSString).lastPathComponent)|\(severity.rawValue)|\(message)" }
}

public struct BuildResult: Codable, Sendable, Equatable {
    public var succeeded: Bool
    public var diagnostics: [Diagnostic]
    public var log: String
    public var seconds: Double

    public init(succeeded: Bool, diagnostics: [Diagnostic] = [], log: String = "", seconds: Double = 0) {
        self.succeeded = succeeded; self.diagnostics = diagnostics; self.log = log; self.seconds = seconds
    }

    public var errors: [Diagnostic] { diagnostics.filter { $0.severity == .error } }
}

public struct TestResult: Codable, Sendable, Equatable {
    public struct Failure: Codable, Sendable, Equatable {
        public var test: String
        public var message: String
        public init(test: String, message: String) { self.test = test; self.message = message }
    }

    public var succeeded: Bool
    public var passed: Int
    public var failures: [Failure]
    /// When the tests did not build, the build's diagnostics.
    public var diagnostics: [Diagnostic]
    public var log: String
    public var seconds: Double

    public init(succeeded: Bool, passed: Int = 0, failures: [Failure] = [], diagnostics: [Diagnostic] = [], log: String = "", seconds: Double = 0) {
        self.succeeded = succeeded; self.passed = passed; self.failures = failures; self.diagnostics = diagnostics
        self.log = log; self.seconds = seconds
    }
}

/// A runner installed on a scratch shelf by the install gate.
public struct InstalledAgent: Codable, Sendable, Equatable {
    public var name: String
    public var folder: URL
    public var executable: URL
    public var words: [String]

    public init(name: String, folder: URL, executable: URL, words: [String]) {
        self.name = name; self.folder = folder; self.executable = executable; self.words = words
    }
}

/// One call over the wire: the answer's JSON, or why it failed.
public struct CallOutcome: Codable, Sendable, Equatable {
    public var output: Data?
    public var failure: String?
    public var refused: Bool
    public var notes: [String]

    public init(output: Data? = nil, failure: String? = nil, refused: Bool = false, notes: [String] = []) {
        self.output = output; self.failure = failure; self.refused = refused; self.notes = notes
    }

    public var succeeded: Bool { output != nil && failure == nil }
}

public protocol ForgeToolchain: Sendable {
    /// "Swift 6.4.2", or nil with the reason in `unavailableReason`.
    func version() async -> String?
    /// Builds `package` (one target when given) with SwiftPM's scratch path at `scratch`.
    func build(package: URL, target: String?, scratch: URL) async throws -> BuildResult
    func test(package: URL, filter: String?, scratch: URL) async throws -> TestResult
    /// Installs a copy of `package` as Craft would (Granite's AgentInstaller) on the shelf at `shelf`.
    func install(package: URL, shelf: URL) async throws -> InstalledAgent
    /// `agent --describe`: the entries it carries, as JSON.
    func describe(_ agent: InstalledAgent) async throws -> Data
    /// One `perform` over the wire, with no host model.
    func perform(_ agent: InstalledAgent, word: String, input: Data, directory: URL) async throws -> CallOutcome
}
