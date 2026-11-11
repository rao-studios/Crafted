import Foundation

/// One value a call found, named, with its unit: `{"name": "total", "value": 57.5, "unit": "USD"}`.
public struct Fact: Codable, Sendable, Equatable, Hashable {
    public var name: String
    public var value: FactValue
    public var unit: String?

    public init(_ name: String, _ value: FactValue, unit: String? = nil) {
        self.name = name; self.value = value; self.unit = unit
    }

    /// The value as a person reads it, with its unit.
    public var said: String {
        let text: String
        switch value {
        case .number(let number): text = FactValue.format(number)
        case .text(let words): text = words
        case .flag(let flag): text = flag ? "yes" : "no"
        }
        return unit.map { "\(text) \($0)" } ?? text
    }
}
