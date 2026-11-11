import Foundation

/// A fact's value: a number, words, or yes and no. Encoded as the bare JSON value.
public enum FactValue: Codable, Sendable, Equatable, Hashable {
    case number(Double)
    case text(String)
    case flag(Bool)

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let flag = try? single.decode(Bool.self) { self = .flag(flag) }
        else if let number = try? single.decode(Double.self) { self = .number(number) }
        else { self = .text(try single.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .number(let number):
            if number == number.rounded(), abs(number) < 1e15 { try single.encode(Int64(number)) } else { try single.encode(number) }
        case .text(let text): try single.encode(text)
        case .flag(let flag): try single.encode(flag)
        }
    }

    public var number: Double? { if case .number(let value) = self { return value }; return nil }

    /// A number as a person reads it: no trailing zeros, at most six places.
    public static func format(_ number: Double) -> String {
        if number == number.rounded(), abs(number) < 1e15 { return String(Int64(number)) }
        var text = String(format: "%.6f", number)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
