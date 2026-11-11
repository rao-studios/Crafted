import Foundation

/// One parameter: its argument label (`_` for none; the name when left out), its name, and its type. Vectors give it
/// by `name`.
public struct ParameterSpec: Codable, Sendable, Equatable {
    public var label: String?
    public var name: String
    public var type: String

    public init(label: String? = nil, name: String, type: String) { self.label = label; self.name = name; self.type = type }

    /// `bill: Double`, `_ text: String`, `in text: String`.
    public var declaration: String {
        guard let label, label != name else { return "\(name): \(type)" }
        return "\(label) \(name): \(type)"
    }

    /// The call site's label: `bill: `, or nothing for `_`.
    public var callLabel: String {
        let said = label ?? name
        return said == "_" ? "" : said + ": "
    }
}
