//  WHAT: The arithmetic a derived vector's exact value claims to come from, evaluated by code: numbers, + - * / ^,
//        parentheses, unary minus. A derived exact value that its own arithmetic does not give is refused, so a vector
//        the model got wrong never becomes a test the port must fail.

import Foundation

public enum Arithmetic {
    /// The value of `expression`, or nil when it is not plain arithmetic.
    public static func evaluate(_ expression: String) -> Double? {
        var parser = Parser(Array(expression.filter { !$0.isWhitespace }))
        guard let value = parser.sum(), parser.index == parser.characters.count, value.isFinite else { return nil }
        return value
    }

    struct Parser {
        let characters: [Character]
        var index = 0

        init(_ characters: [Character]) { self.characters = characters }

        mutating func sum() -> Double? {
            guard var value = product() else { return nil }
            while index < characters.count, characters[index] == "+" || characters[index] == "-" {
                let op = characters[index]; index += 1
                guard let right = product() else { return nil }
                value = op == "+" ? value + right : value - right
            }
            return value
        }

        mutating func product() -> Double? {
            guard var value = power() else { return nil }
            while index < characters.count, characters[index] == "*" || characters[index] == "/" {
                let op = characters[index]; index += 1
                guard let right = power() else { return nil }
                value = op == "*" ? value * right : value / right
            }
            return value
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if index < characters.count, characters[index] == "^" {
                index += 1
                guard let exponent = power() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        mutating func unary() -> Double? {
            if index < characters.count, characters[index] == "-" { index += 1; return unary().map { -$0 } }
            if index < characters.count, characters[index] == "+" { index += 1; return unary() }
            if index < characters.count, characters[index] == "(" {
                index += 1
                guard let value = sum(), index < characters.count, characters[index] == ")" else { return nil }
                index += 1
                return value
            }
            let start = index
            while index < characters.count, characters[index].isNumber || characters[index] == "." || characters[index] == "e"
                    || ((characters[index] == "-" || characters[index] == "+") && index > start && characters[index - 1] == "e") {
                index += 1
            }
            return Double(String(characters[start..<index]))
        }
    }
}
