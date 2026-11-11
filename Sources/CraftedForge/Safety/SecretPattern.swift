//  WHAT: One shape of secret: a regular expression, which group of it is the secret (what `redact` replaces), a
//        check on the value that turns away look-alikes, and what to call it in a finding.
//  OUT:  SecretScan+Patterns (the table), PrivacyScan.

import Foundation

struct SecretPattern: @unchecked Sendable {
    let regex: NSRegularExpression
    /// The capture group that is the secret; 0 is the whole match.
    let group: Int
    /// Whether the value (the group's text) really is one, given the whole match and the text.
    let accept: (String, NSTextCheckingResult, NSString) -> Bool
    /// What it looks like, for the finding.
    let describe: (NSTextCheckingResult, NSString) -> String

    init(_ pattern: String, options: NSRegularExpression.Options = [], group: Int = 0, what: String,
         accept: @escaping (String, NSTextCheckingResult, NSString) -> Bool = { _, _, _ in true }) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
        self.group = group
        self.accept = accept
        self.describe = { _, _ in what }
    }

    init(_ pattern: String, options: NSRegularExpression.Options = [], group: Int,
         accept: @escaping (String, NSTextCheckingResult, NSString) -> Bool,
         describe: @escaping (NSTextCheckingResult, NSString) -> String) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
        self.group = group
        self.accept = accept
        self.describe = describe
    }
}
