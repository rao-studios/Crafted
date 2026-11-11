//  WHAT: Finds licence notices a package cannot carry under its own licence: a GPL, LGPL or AGPL notice in a file
//        of a package that is not GPL-3.0 (a lifted file keeps its header, and that header binds the whole package).
//  OUT:  The ship gate.
//  PIN:  DOCUMENTS ARE EXEMPT. LICENSE, NOTICE, README, PROVENANCE and CHANGELOG may name any licence: saying where a
//        port came from is the point of them.

import CraftedCore
import Foundation

public enum LicenceScan {
    /// Each notice in `text` that `licence` cannot carry, with its line.
    public static func hits(in text: String, path: String, packageLicence licence: ListingLicence?) -> [ScanHit] {
        guard !isDocument(path) else { return [] }
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        let lines = LineIndex(ns)
        var hits: [ScanHit] = []
        for (pattern, name, allowedUnder) in notices {
            if let licence, allowedUnder.contains(licence) { continue }
            for match in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                hits.append(ScanHit(what: "a \(name) notice", path: path, line: lines.line(at: match.range.location),
                                    kind: .licence, range: match.range))
                break
            }
        }
        return hits
    }

    /// A licence, notice, README, provenance, changelog or authors file, at any depth (`OFL-LICENSE.txt` too).
    static func isDocument(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.uppercased()
        guard ["", "TXT", "MD", "MARKDOWN", "RTF"].contains((name as NSString).pathExtension) else { return false }
        if ["LICENSE", "LICENCE", "COPYING", "NOTICE"].contains(where: { name.contains($0) }) { return true }
        return ["README", "PROVENANCE", "CHANGELOG", "AUTHORS"].contains { name.hasPrefix($0) }
    }

    /// Copyleft notices, and the package licences that may carry each.
    static let notices: [(NSRegularExpression, String, Swift.Set<ListingLicence>)] = [
        (regex(#"GNU Affero General Public License|SPDX-License-Identifier:\s*AGPL"#), "AGPL", []),
        (regex(#"GNU Lesser General Public License|SPDX-License-Identifier:\s*LGPL"#), "LGPL", [.gpl3]),
        (regex(#"GNU General Public License|SPDX-License-Identifier:\s*GPL"#), "GPL", [.gpl3]),
    ]

    static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
