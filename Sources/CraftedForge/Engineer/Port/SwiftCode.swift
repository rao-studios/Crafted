import Foundation

/// The Swift in a model's answer: the last fenced block marked swift (or the only fenced block), else the answer whole.
enum SwiftCode {
    static func extract(_ answer: String) -> String {
        let blocks = fenced(answer)
        let swift = blocks.filter { $0.language.lowercased() == "swift" }
        let body = (swift.last ?? blocks.last)?.text ?? answer
        return body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func fenced(_ text: String) -> [(language: String, text: String)] {
        var blocks: [(String, String)] = []
        var language: String?
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let open = language {
                    blocks.append((open, lines.joined(separator: "\n")))
                    language = nil
                    lines = []
                } else {
                    language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if language != nil { lines.append(line) }
        }
        return blocks
    }
}
