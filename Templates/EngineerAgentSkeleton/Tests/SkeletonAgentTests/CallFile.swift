import Foundation

/// A command's canonical call, as Calls/<command>.call.json holds it: the input a host would send, files the call
/// reads (written into a fresh project folder first), and what the answer must say.
struct CallFile: Decodable {
    var command: String
    var input: [String: CallJSON]
    var files: [String: String]?
    var expect: CallExpectation?
}
