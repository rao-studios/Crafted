//  WHAT: Makes model-written JSON strict enough to parse: invalid escapes doubled, raw line breaks escaped,
//        backtick strings quoted. The JSON half of Craft's LenientMistralCalls (CraftCore/Inference/ToolCalls),
//        without its tool-call recovery, which Crafted has no use for.
//  OUT:  JSONValue.object(inModelText:), the forge's structured asks.

import Foundation

public enum LenientJSON {
    public static func parseObject(_ json: String) -> JSONValue? {
        for candidate in [json, repairJSON(json)] {
            if let value = try? JSONValue.parse(Data(candidate.utf8)), case .object = value { return value }
        }
        return nil
    }

    /// `"key":\`text\`` → `"key":"text"`: a backtick-delimited string outside any quoted string becomes a
    /// quoted one, its inner quotes escaped and its raw line breaks written as `\\n`. Backticks inside a
    /// quoted string are text and stay. Escapes inside the backticks (`\\n`) are kept as written — they are
    /// the string's own escapes — except a backslash before a backtick, which only ends the literal.
    static func backticksToQuotes(_ json: String) -> String {
        var out = ""
        out.reserveCapacity(json.count + 8)
        var inQuotes = false
        var inBackticks = false
        var escaped = false
        for character in json {
            if inQuotes {
                out.append(character)
                if escaped { escaped = false } else if character == "\\" { escaped = true } else if character == "\"" { inQuotes = false }
                continue
            }
            if inBackticks {
                if escaped {
                    escaped = false
                    if character == "`" { out.append("`") } else { out.append("\\"); out.append(character) }
                } else if character == "\\" {
                    escaped = true
                } else if character == "`" {
                    inBackticks = false
                    out.append("\"")
                } else if character == "\"" {
                    out += "\\\""
                } else if character == "\n" {
                    out += "\\n"
                } else if character == "\r" {
                    out += "\\r"
                } else if character == "\t" {
                    out += "\\t"
                } else {
                    out.append(character)
                }
                continue
            }
            switch character {
            case "\"": inQuotes = true; out.append(character)
            case "`": inBackticks = true; out.append("\"")
            default: out.append(character)
            }
        }
        return out
    }

    /// Makes model-written JSON strict: inside strings, a backslash that does not start
    /// a valid escape is doubled (`\(` → `\\(`), and raw newlines and tabs are escaped.
    public static func repairJSON(_ json: String) -> String {
        var out = ""
        out.reserveCapacity(json.count + 16)
        let characters = Array(json)
        var inString = false
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if !inString {
                if character == "\"" { inString = true }
                out.append(character)
                index += 1
                continue
            }
            switch character {
            case "\"":
                inString = false
                out.append(character)
            case "\\":
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                if let next, "\"\\/bfnrt".contains(next) {
                    out.append(character); out.append(next); index += 1
                } else if next == "u", index + 5 < characters.count, characters[(index + 2)...(index + 5)].allSatisfy(\.isHexDigit) {
                    out.append(character)
                } else if next == "`" {
                    // PIN: a backslash before a backtick is the model escaping the backtick, as in Markdown — never
                    // source. Kept as `\\\`` it reached two files as text and both builds failed on "Expected unicode
                    // escape" (`className={\`${…}\`}`, 2026-10-05 and 2026-10-06).
                    out.append("`"); index += 1
                } else {
                    out += "\\\\"
                }
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default: out.append(character)
            }
            index += 1
        }
        return out
    }
}
