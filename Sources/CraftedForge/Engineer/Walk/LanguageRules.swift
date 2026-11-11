//  WHAT: What code reads from a source file without a model: the files it imports (resolved inside the project), an
//        outline of its declarations, and the lines that touch the world (files, network, processes, the clock,
//        randomness, the environment, output, entry). Swift, Python and JavaScript/TypeScript have rules of their own;
//        every other language gets line heuristics (GenericRules).
//  OUT:  The walk's order (imports, leaves first), each card's prompt (outline and effects), the effect lens.

import Foundation

protocol LanguageRules: Sendable {
    /// Project paths `path` imports, among `paths`.
    func imports(_ lines: [String], path: String, paths: Swift.Set<String>) -> [String]
    func outline(_ lines: [String]) -> [OutlineItem]
    func effects(_ lines: [String]) -> [EffectLine]
}

extension LanguageRules {
    /// Each line that matches one of `patterns` (regex → kind).
    func matches(_ lines: [String], _ patterns: [(String, String)]) -> [EffectLine] {
        var found: [EffectLine] = []
        for (index, line) in lines.enumerated() {
            for (pattern, kind) in patterns where line.range(of: pattern, options: .regularExpression) != nil {
                found.append(EffectLine(kind: kind, line: index + 1, detail: line.trimmingCharacters(in: .whitespaces)))
                break
            }
        }
        return found
    }

    /// Each line that opens a declaration matching `pattern`.
    func declarations(_ lines: [String], _ pattern: String) -> [OutlineItem] {
        lines.enumerated().compactMap { index, line in
            line.range(of: pattern, options: .regularExpression) != nil
                ? OutlineItem(line: index + 1, text: line.trimmingCharacters(in: .whitespaces)) : nil
        }
    }

    /// The first capture of `pattern` on each line.
    func captures(_ lines: [String], _ pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return lines.compactMap { line in
            let ns = line as NSString
            guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
            for group in 1..<match.numberOfRanges where match.range(at: group).location != NSNotFound {
                return ns.substring(with: match.range(at: group))
            }
            return nil
        }
    }
}
