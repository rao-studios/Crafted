import Foundation

/// Reading a model's JSON loosely: a number written as a string, a boolean as "yes", an element of a list that does
/// not decode dropped rather than the whole list. A local model's JSON is loose; a piece should not be lost to a stray
/// quote. (After PlateAgent's PlateLoose.)
public enum PieceLoose {
    /// A value that decodes, or nothing, never a thrown error: one bad element of a list is dropped alone.
    public struct Element<T: Decodable>: Decodable {
        public let value: T?
        public init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    public static func string<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return text }
        if let number = try? c.decodeIfPresent(Int.self, forKey: key) { return String(number) }
        if let number = try? c.decodeIfPresent(Double.self, forKey: key) { return String(number) }
        return nil
    }

    public static func int<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int? {
        if let number = try? c.decodeIfPresent(Int.self, forKey: key) { return number }
        if let number = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(number) }
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return Int(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    public static func double<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let number = try? c.decodeIfPresent(Double.self, forKey: key) { return number }
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return Double(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    public static func bool<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Bool? {
        if let flag = try? c.decodeIfPresent(Bool.self, forKey: key) { return flag }
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return ["true", "yes", "1", "on"].contains(text.lowercased()) }
        if let number = try? c.decodeIfPresent(Int.self, forKey: key) { return number != 0 }
        return nil
    }

    public static func list<K: CodingKey, T: Decodable>(_ c: KeyedDecodingContainer<K>, _ key: K, of type: T.Type) -> [T] {
        ((try? c.decodeIfPresent([Element<T>].self, forKey: key)) ?? nil)?.compactMap(\.value) ?? []
    }

    /// An id made from a name: lowercase letters and digits, words joined by `-`.
    public static func slug(_ text: String) -> String {
        let words = text.lowercased().split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
        return words.joined(separator: "-")
    }

    /// A decoding error as a sentence: where it went wrong and what was wrong.
    public static func describe(_ error: Error) -> String {
        guard let error = error as? DecodingError else { return "\(error)" }
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
            return keys.isEmpty ? "the file" : keys.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context): return "\(path(context)) has no \"\(key.stringValue)\""
        case .typeMismatch(let type, let context): return "\(path(context)) should be \(type)"
        case .valueNotFound(let type, let context): return "\(path(context)) should be a \(type)"
        case .dataCorrupted(let context): return "\(path(context)): \(context.debugDescription)"
        @unknown default: return "\(error)"
        }
    }
}

extension String {
    /// The text, or nil when it is only spaces.
    public var nonEmptyText: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
