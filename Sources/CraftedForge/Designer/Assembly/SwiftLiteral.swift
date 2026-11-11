import Foundation

/// Text as a Swift string literal: quoted, with backslashes, quotes, line breaks and anything unprintable escaped, so a
/// designer's name can never end the literal or open an interpolation.
public enum SwiftLiteral {
    public static func string(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F { out += "\\u{\(String(scalar.value, radix: 16))}" } else { out.unicodeScalars.append(scalar) }
            }
        }
        return out + "\""
    }

    public static func optional(_ text: String?) -> String { text.map(string) ?? "nil" }
}
