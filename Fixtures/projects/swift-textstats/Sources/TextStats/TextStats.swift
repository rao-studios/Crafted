import Foundation

/// Counts and readability scores for a text.
public struct TextStats: Equatable, Sendable {
    public var words: Int
    public var sentences: Int
    public var syllables: Int

    public init(_ text: String) {
        let tokens = TextStats.words(in: text)
        words = tokens.count
        sentences = max(1, text.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)
        syllables = tokens.reduce(0) { $0 + TextStats.syllables(in: $1) }
    }

    /// Flesch reading ease: higher is easier.
    public var readingEase: Double {
        guard words > 0 else { return 0 }
        return 206.835 - 1.015 * Double(words) / Double(sentences) - 84.6 * Double(syllables) / Double(words)
    }

    /// Flesch–Kincaid grade level.
    public var grade: Double {
        guard words > 0 else { return 0 }
        return 0.39 * Double(words) / Double(sentences) + 11.8 * Double(syllables) / Double(words) - 15.59
    }

    /// Minutes to read at 238 words a minute.
    public var minutes: Double { Double(words) / 238 }

    static func words(in text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
    }

    /// Vowel groups, less a silent final e, at least one.
    static func syllables(in word: String) -> Int {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var previous = false
        for character in word {
            let vowel = vowels.contains(character)
            if vowel && !previous { count += 1 }
            previous = vowel
        }
        if word.hasSuffix("e") && count > 1 { count -= 1 }
        return max(1, count)
    }
}
