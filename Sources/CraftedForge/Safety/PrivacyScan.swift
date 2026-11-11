//  WHAT: Finds what would say who made a package or whom it is about: a path in someone's home folder
//        (/Users/<name>/, /home/<name>/) anywhere, and email addresses or phone numbers in shipped resources
//        (data, fixtures, vectors, assets).
//  OUT:  The ship gate; the pipelines may scan what they carry with it too.
//  PIN:  NEVER THE VALUE, as with secrets: a hit says what and where.
//  PIN:  CODE MAY NAME AN ADDRESS; DATA MAY NOT. Emails and phones are looked for in resources only (a README crediting
//        its author is fine; a carried CSV of customers is not). Home paths are looked for everywhere.

import Foundation

public enum PrivacyScan {
    /// Each private detail in `text` as a finding naming `path` and the line. `path` decides whether the text is a
    /// resource (emails and phones looked for); nil counts as one.
    public static func findings(in text: String, path: String?) -> [Finding] {
        var seen: Swift.Set<String> = []
        return hits(in: text, path: path).compactMap { seen.insert($0.sentence).inserted ? $0.finding : nil }
    }

    public static func hits(in text: String, path: String?) -> [ScanHit] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        let full = NSRange(location: 0, length: ns.length)
        let lines = LineIndex(ns)
        let patterns = path.map(isResource) ?? true ? homePatterns + resourcePatterns : homePatterns
        var taken: [NSRange] = []
        var hits: [ScanHit] = []
        for pattern in patterns {
            for match in pattern.regex.matches(in: text, range: full) {
                let range = match.range(at: pattern.group)
                guard range.location != NSNotFound, pattern.accept(ns.substring(with: range), match, ns) else { continue }
                guard !taken.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { continue }
                taken.append(range)
                hits.append(ScanHit(what: pattern.describe(match, ns), path: path, line: lines.line(at: range.location),
                                    kind: .info, range: range))
            }
        }
        return hits.sorted { $0.range.location < $1.range.location }
    }

    /// `text` with home-folder paths made `~/` and resource emails and phones redacted.
    public static func redact(_ text: String, path: String? = nil) -> String {
        let out = NSMutableString(string: text)
        for hit in hits(in: text, path: path).sorted(by: { $0.range.location > $1.range.location }) {
            out.replaceCharacters(in: hit.range, with: hit.what == homeWhat ? "~/" : SecretScan.placeholder)
        }
        return out as String
    }

    /// Whether a shipped path is data rather than code or a document (a README, a licence, a notice, at any depth:
    /// a font's licence names its foundry's address).
    public static func isResource(_ path: String) -> Bool {
        let parts = path.split(separator: "/").map(String.init)
        if LicenceScan.isDocument(path) { return false }
        if parts.contains(where: { resourceFolders.contains($0) }) { return true }
        guard parts.count > 1 else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        return dataExtensions.contains(ext)
    }

    static let resourceFolders: Swift.Set<String> = ["Resources", "Fixtures", "Assets", "Vectors", "Calls", "Data", "Samples"]
    static let dataExtensions: Swift.Set<String> = ["json", "csv", "tsv", "txt", "yaml", "yml", "plist", "xml", "strings", "html", "css"]
    static let homeWhat = "a path in a home folder"

    /// Folder names under /Users or /home that name no one.
    static let anonymousHomes: Swift.Set<String> = ["shared", "guest", "runner", "user", "username", "name", "me", "you",
                                                     "example", "someone", "xxx", "builder", "ubuntu", "admin", "root"]

    static let homePatterns: [SecretPattern] = [
        SecretPattern(#"(?<![A-Za-z0-9._~\-])/(?:Users|home)/([A-Za-z0-9._\-]+)/"#, group: 0, what: homeWhat,
                      accept: { _, match, text in
                          let name = text.substring(with: match.range(at: 1))
                          return !anonymousHomes.contains(name.lowercased())
                      }),
    ]

    static let resourcePatterns: [SecretPattern] = [
        SecretPattern(#"(?<![A-Za-z0-9._%+\-])([A-Za-z0-9._%+\-]+)@((?:[A-Za-z0-9\-]+\.)+[A-Za-z]{2,24})(?![A-Za-z0-9\-])"#,
                      group: 0, what: "an email address", accept: { _, match, text in
                          isPersonalEmail(local: text.substring(with: match.range(at: 1)), domain: text.substring(with: match.range(at: 2)))
                      }),
        SecretPattern(#"(?<![\w.+\-])(?:\+\d{1,3}[ .\-]?)?(?:\(\d{3}\)[ ]?|\d{3}[ .\-])\d{3}[ .\-]\d{4}(?![\w.\-])"#,
                      what: "a phone number"),
        SecretPattern(#"(?<![\w.+\-])\+\d{1,3}(?:[ .\-]\d{1,4}){2,5}(?![\w.\-])"#, what: "a phone number",
                      accept: { value, _, _ in (8...15).contains(value.filter(\.isNumber).count) }),
    ]

    /// Not a documentation domain, a git remote, a no-reply sender or an image's `@2x` name.
    static func isPersonalEmail(local: String, domain: String) -> Bool {
        let domain = domain.lowercased()
        let local = local.lowercased()
        if ["git", "noreply", "no-reply", "donotreply"].contains(local) { return false }
        let example = ["example.com", "example.org", "example.net"]
        if example.contains(where: { domain == $0 || domain.hasSuffix("." + $0) }) { return false }
        let tld = domain.split(separator: ".").last.map(String.init) ?? ""
        if ["example", "test", "invalid", "localhost", "local"].contains(tld) { return false }
        if ["png", "jpg", "jpeg", "pdf", "svg", "json", "swift", "webp", "gif", "heic"].contains(tld) { return false }
        if let first = domain.split(separator: ".").first, first.range(of: #"^\d+x$"#, options: .regularExpression) != nil { return false }
        return true
    }
}
