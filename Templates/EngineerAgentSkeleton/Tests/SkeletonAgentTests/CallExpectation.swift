import Foundation

/// What a canonical call's answer must say.
struct CallExpectation: Decodable {
    /// Facts the answer must carry: numbers within `tolerance`, text exactly.
    var facts: [String: CallJSON]?
    var tolerance: Double?
    /// How many files it must write.
    var files: Int?
    /// Words that must appear in its notes.
    var notes: [String]?
}
