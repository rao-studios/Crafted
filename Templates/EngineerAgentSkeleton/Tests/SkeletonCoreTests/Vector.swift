import Foundation

/// One vector: a function called with arguments, and what must hold of its result: an exact value (`expect`, numbers
/// within `tolerance`), an error (`expectError`), or a property.
struct Vector: Decodable {
    var name: String
    var function: String
    var args: [String: VectorJSON]
    var expect: VectorJSON?
    var expectError: Bool?
    var property: VectorProperty?
    var tolerance: Double?
    /// `source-test` or `derived`.
    var origin: String?
    var evidence: String?
}
