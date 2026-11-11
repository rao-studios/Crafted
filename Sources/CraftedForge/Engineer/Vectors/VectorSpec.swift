import CraftedCore
import Foundation

/// One vector as the coder writes it and the package's runner reads it (Tests/<Core>Tests/Vectors/<Unit>.vectors.json):
/// a contract function called with JSON arguments, and its exact value, error or property. `held` is the forge's own:
/// a held vector runs in the tests and is never shown to the port.
public struct VectorSpec: Codable, Sendable, Equatable {
    public var name: String
    public var function: String
    public var args: [String: JSONValue]
    public var expect: JSONValue?
    public var expectError: Bool?
    public var property: JSONValue?
    public var tolerance: Double?
    /// The arithmetic an exact derived value comes from, recomputed by code.
    public var arithmetic: String?
    /// `source-test` or `derived`.
    public var origin: String
    public var evidence: String?
    public var held: Bool?

    enum CodingKeys: String, CodingKey { case name, function, args, expect, expectError, property, tolerance, arithmetic, origin, evidence, held }

    public init(name: String, function: String, args: [String: JSONValue], expect: JSONValue? = nil, expectError: Bool? = nil,
                property: JSONValue? = nil, tolerance: Double? = nil, arithmetic: String? = nil, origin: String = "derived",
                evidence: String? = nil, held: Bool? = nil) {
        self.name = name; self.function = function; self.args = args; self.expect = expect; self.expectError = expectError
        self.property = property; self.tolerance = tolerance; self.arithmetic = arithmetic; self.origin = origin
        self.evidence = evidence; self.held = held
    }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decode(String.self, forKey: .name)
        function = try keyed.decode(String.self, forKey: .function)
        args = try keyed.decodeIfPresent([String: JSONValue].self, forKey: .args) ?? [:]
        expect = try keyed.decodeIfPresent(JSONValue.self, forKey: .expect)
        expectError = try keyed.decodeIfPresent(Bool.self, forKey: .expectError)
        property = try keyed.decodeIfPresent(JSONValue.self, forKey: .property)
        tolerance = try keyed.decodeIfPresent(Double.self, forKey: .tolerance)
        arithmetic = try keyed.decodeIfPresent(String.self, forKey: .arithmetic)
        origin = try keyed.decodeIfPresent(String.self, forKey: .origin) ?? "derived"
        evidence = try keyed.decodeIfPresent(String.self, forKey: .evidence)
        held = try keyed.decodeIfPresent(Bool.self, forKey: .held)
    }

    /// One line for a port prompt: the call and what must hold.
    public var line: String {
        let call = "\(function)(" + args.keys.sorted().map { "\($0): \(args[$0]?.compact ?? "null")" }.joined(separator: ", ") + ")"
        if expectError == true { return "\(call) throws" }
        if let expect { return "\(call) == \(expect.compact)" + (tolerance.map { " (± \($0))" } ?? "") }
        if let property { return "\(call): \(property.compact)" }
        return call
    }
}

