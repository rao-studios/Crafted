//  WHAT: The Swift types a contract may name, read and checked: `Int Double Bool String Date Data Decimal`, `[T]`,
//        `[String: T]`, `T?`, and declared domain types. No generics, closures or tuples, so the vector runner can
//        make every argument from JSON and compare every result.

import Foundation

public enum SwiftTypeName {
    public static let builtins: Swift.Set<String> = ["Int", "Double", "Bool", "String", "Date", "Data", "Decimal"]

    /// A type, read.
    public indirect enum Shape: Equatable, Sendable {
        case named(String)
        case array(Shape)
        case dictionary(Shape)
        case optional(Shape)
    }

    /// `text` read as a shape, or nil when it is not one a contract may name.
    public static func parse(_ text: String) -> Shape? {
        var characters = Array(text.filter { !$0.isWhitespace })
        guard !characters.isEmpty else { return nil }
        var optional = 0
        while characters.last == "?" { characters.removeLast(); optional += 1 }
        guard optional <= 1, !characters.isEmpty else { return nil }
        let body = String(characters)
        var shape: Shape
        if body.hasPrefix("[") && body.hasSuffix("]") {
            let inner = String(body.dropFirst().dropLast())
            if let colon = topLevelColon(inner) {
                let key = String(inner[..<colon])
                guard key == "String", let value = parse(String(inner[inner.index(after: colon)...])) else { return nil }
                shape = .dictionary(value)
            } else {
                guard let element = parse(inner) else { return nil }
                shape = .array(element)
            }
        } else {
            guard isIdentifier(body) else { return nil }
            shape = .named(body)
        }
        if optional == 1 { shape = .optional(shape) }
        return shape
    }

    /// Why `text` is not a type a contract may name with `declared` types, or nil.
    public static func problem(_ text: String, declared: Swift.Set<String>) -> String? {
        guard let shape = parse(text) else {
            return "`\(text)` is not a type a contract may name: use Int, Double, Bool, String, Date, Data, Decimal, [T], [String: T], T? or a declared type"
        }
        for name in names(in: shape) where !builtins.contains(name) && !declared.contains(name) {
            return "`\(text)` names \(name), which is not a declared type"
        }
        return nil
    }

    /// The declared (non-builtin) type names in `text`.
    public static func named(in text: String) -> Swift.Set<String> {
        guard let shape = parse(text) else { return [] }
        return Swift.Set(names(in: shape).filter { !builtins.contains($0) })
    }

    static func names(in shape: Shape) -> [String] {
        switch shape {
        case .named(let name): return [name]
        case .array(let inner), .dictionary(let inner), .optional(let inner): return names(in: inner)
        }
    }

    public static func isIdentifier(_ text: String) -> Bool {
        guard let first = text.first, first.isASCII, first.isLetter || first == "_" else { return false }
        return text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }

    private static func topLevelColon(_ text: String) -> String.Index? {
        var depth = 0
        for index in text.indices {
            switch text[index] {
            case "[": depth += 1
            case "]": depth -= 1
            case ":" where depth == 0: return index
            default: break
            }
        }
        return nil
    }
}
