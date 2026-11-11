import Foundation

/// A JSON value as a vector holds it: arguments, expected results, property values.
indirect enum VectorJSON: Codable, Equatable, Sendable, CustomStringConvertible {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([VectorJSON])
    case object([String: VectorJSON])

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .null }
        else if let value = try? single.decode(Bool.self) { self = .bool(value) }
        else if let value = try? single.decode(Double.self) { self = .number(value) }
        else if let value = try? single.decode(String.self) { self = .string(value) }
        else if let value = try? single.decode([VectorJSON].self) { self = .array(value) }
        else { self = .object(try single.decode([String: VectorJSON].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .null: try single.encodeNil()
        case .bool(let value): try single.encode(value)
        case .number(let value): try single.encode(value)
        case .string(let value): try single.encode(value)
        case .array(let value): try single.encode(value)
        case .object(let value): try single.encode(value)
        }
    }

    /// Any encodable result, as JSON: dates ISO 8601, data base64, decimals as numbers.
    static func encoding<T: Encodable>(_ value: T) throws -> VectorJSON {
        try JSONDecoder().decode(VectorJSON.self, from: VectorCoding.encoder.encode(value))
    }

    /// `path` ("tip", "rows.0.total") inside this value.
    func at(_ path: String?) -> VectorJSON? {
        guard let path, !path.isEmpty else { return self }
        var current: VectorJSON? = self
        for key in path.split(separator: ".") {
            switch current {
            case .object(let object)?: current = object[String(key)]
            case .array(let array)?: current = Int(key).flatMap { array.indices.contains($0) ? array[$0] : nil }
            default: return nil
            }
        }
        return current
    }

    var number: Double? { if case .number(let value) = self { return value }; return nil }
    var string: String? { if case .string(let value) = self { return value }; return nil }
    var array: [VectorJSON]? { if case .array(let value) = self { return value }; return nil }

    var description: String {
        (try? String(decoding: VectorCoding.encoder.encode(self), as: UTF8.self)) ?? "?"
    }

    /// Equal, numbers within `tolerance`.
    func matches(_ other: VectorJSON, tolerance: Double) -> Bool {
        switch (self, other) {
        case (.number(let a), .number(let b)): return abs(a - b) <= max(tolerance, 1e-9 * max(abs(a), abs(b), 1))
        case (.array(let a), .array(let b)): return a.count == b.count && zip(a, b).allSatisfy { $0.matches($1, tolerance: tolerance) }
        case (.object(let a), .object(let b)):
            return Set(a.keys) == Set(b.keys) && a.allSatisfy { key, value in b[key].map { value.matches($0, tolerance: tolerance) } ?? false }
        default: return self == other
        }
    }
}
