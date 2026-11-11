//  WHAT: The parse rung, in code and in a millisecond: a candidate's braces, brackets and parentheses balance outside
//        comments and strings, and it is not empty. What the compiler would refuse first, refused before a build.

import Foundation

public enum ShapeCheck {
    public static func problems(_ text: String) -> [String] {
        let code = StaticScan.stripped(text)
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return ["the file is empty"] }
        var stack: [(Character, Int)] = []
        var line = 1
        let pairs: [Character: Character] = [")": "(", "]": "[", "}": "{"]
        for character in code {
            if character == "\n" { line += 1; continue }
            if "([{".contains(character) { stack.append((character, line)); continue }
            if let open = pairs[character] {
                guard let last = stack.popLast() else { return ["line \(line): a \(character) closes nothing"] }
                if last.0 != open { return ["line \(line): \(character) closes the \(last.0) opened on line \(last.1)"] }
            }
        }
        if let open = stack.last { return ["line \(open.1): the \(open.0) opened here is never closed"] }
        return []
    }
}
