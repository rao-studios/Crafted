//  WHAT: The secret shapes SecretScan looks for, most specific first: a private-key block, then each provider's key
//        prefix, then JSON Web Tokens, connection strings with a password, values assigned to key-like names, and
//        last any long run of random-looking key characters.
//  PIN:  ORDER IS MEANING. The first pattern to claim a span names it (SecretScan never lets two claim one).
//  PIN:  BOUNDED NAMES. A key-like name is matched from a word's start and at most 40 characters either side of
//        its keyword: an unbounded `[A-Za-z0-9_]*` before the keyword backtracks over every long identifier run, and
//        a 1.7 MB JSON of tickers took minutes (StoicAgent, 2026-11-10).

import Foundation

extension SecretScan {
    static let patterns: [SecretPattern] = [
        // -----BEGIN RSA PRIVATE KEY----- … -----END RSA PRIVATE KEY-----, or to the end when cut off.
        SecretPattern(#"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY(?: BLOCK)?-----[\s\S]*?(?:-----END (?:[A-Z0-9]+ )*PRIVATE KEY(?: BLOCK)?-----|\z)"#,
                      what: "a private key", accept: { value, _, _ in privateKeyBody(value) }),
        SecretPattern(#"\b(?:AKIA|ASIA|ABIA|ACCA)[0-9A-Z]{16}\b"#, what: "an AWS access key"),
        SecretPattern(#"(?i)aws_?secret_?access_?key["']?\s*[:=]\s*["']?([A-Za-z0-9/+=]{40})(?![A-Za-z0-9/+=])"#,
                      group: 1, what: "an AWS secret key"),
        SecretPattern(#"\bgh[pousr]_[A-Za-z0-9]{36,255}\b"#, what: "a GitHub token"),
        SecretPattern(#"\bgithub_pat_[A-Za-z0-9_]{22,255}\b"#, what: "a GitHub token"),
        SecretPattern(#"\bxox[abposre]-[A-Za-z0-9-]{10,250}"#, what: "a Slack token"),
        SecretPattern(#"https://hooks\.slack\.com/services/[A-Za-z0-9/_-]{20,}"#, what: "a Slack webhook"),
        SecretPattern(#"\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,247}\b"#, what: "a Stripe secret key"),
        SecretPattern(#"\bAIza[0-9A-Za-z_-]{35}(?![0-9A-Za-z_-])"#, what: "a Google API key"),
        SecretPattern(#"\bsk-ant-[A-Za-z0-9_-]{20,}"#, what: "an Anthropic API key"),
        SecretPattern(#"\bsk-(?:proj-|svcacct-|admin-)?[A-Za-z0-9_-]{20,}"#, what: "an OpenAI API key",
                      accept: { value, _, _ in SecretValue.hasDigit(value) && SecretValue.entropy(value) >= 3.5 }),
        SecretPattern(#"\bhf_[A-Za-z0-9]{30,}\b"#, what: "a Hugging Face token"),
        SecretPattern(#"\bnpm_[A-Za-z0-9]{36}\b"#, what: "an npm token"),
        SecretPattern(#"\bSG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}\b"#, what: "a SendGrid key"),
        SecretPattern(#"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#, what: "a JSON Web Token"),
        // scheme://user:password@host: the password only, so a redacted prompt keeps the shape.
        SecretPattern(#"\b[A-Za-z][A-Za-z0-9+.\-]{1,20}://[^\s:/@'"`<>]+:([^\s@/'"`<>]+)@[A-Za-z0-9._\-]+"#,
                      group: 1, what: "a password in a connection string",
                      accept: { value, _, _ in !SecretValue.isPlaceholder(value) && !["password", "pass", "pwd", "secret"].contains(value.lowercased()) }),
        // apiKey = "…", "client_secret": "…", let token: String = "…"
        SecretPattern(#"(?i)\b([A-Za-z0-9_.\-]{0,40}?(?:api[_.\-]?key|apikey|secret|token|passw(?:or)?d|pwd|private[_.\-]?key|access[_.\-]?key|auth[_.\-]?key|credential)[A-Za-z0-9_.\-]{0,40})["']?(?:\s*:\s*[A-Za-z][A-Za-z0-9?<>\[\]]*)?\s*(?::=|=>|[:=])\s*(["'`])([^"'`\s\\]{12,})\2"#,
                      group: 3, accept: { value, _, _ in SecretValue.isAssignedSecret(value) },
                      describe: assignedTo),
        // API_KEY=… in an environment-style file.
        SecretPattern(#"(?m)^[ \t]*(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]{0,40}?(?:KEY|SECRET|TOKEN|PASSWORD|PASSWD|PWD|CREDENTIALS?)[A-Za-z0-9_]{0,40})[ \t]*=[ \t]*([A-Za-z0-9+/=_\-.!@$%^&*~:]{12,})(?=[ \t]*(?:#.*)?$)"#,
                      group: 2, accept: { value, _, _ in SecretValue.isAssignedSecret(value) }, describe: assignedTo),
        // api_key: … in YAML.
        SecretPattern(#"(?im)^[ \t\-]*([a-z0-9_.\-]{0,40}?(?:api[_\-]?key|apikey|secret|token|password|passwd)[a-z0-9_.\-]{0,40})[ \t]*:[ \t]+([A-Za-z0-9+/=_\-.!@$%^&*~]{12,})[ \t]*$"#,
                      group: 2, accept: { value, _, _ in SecretValue.isAssignedSecret(value) }, describe: assignedTo),
        SecretPattern(#"[A-Za-z0-9+/=_\-]{32,}"#, what: "a long random string, likely a key",
                      accept: { value, match, text in SecretValue.isRandomRun(value, match, text) }),
    ]

    /// "a secret assigned to apiKey": the name, never the value.
    static func assignedTo(_ match: NSTextCheckingResult, _ text: NSString) -> String {
        let range = match.range(at: 1)
        guard range.location != NSNotFound, range.length > 0 else { return "a secret value" }
        let name = text.substring(with: range).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return "a secret assigned to \(name.prefix(48))"
    }

    /// A key block with a body, not a parser that only names the header.
    static func privateKeyBody(_ block: String) -> Bool {
        guard let close = block.range(of: "-----", range: block.index(block.startIndex, offsetBy: 5)..<block.endIndex) else { return false }
        var body = block[close.upperBound...].drop(while: { $0.isWhitespace })
        while body.hasPrefix("\\n") { body = body.dropFirst(2).drop(while: { $0.isWhitespace }) }
        let head = body.prefix(64)
        return head.filter({ $0.isASCII && ($0.isLetter || $0.isNumber || "+/=".contains($0)) }).count >= 40
    }
}
