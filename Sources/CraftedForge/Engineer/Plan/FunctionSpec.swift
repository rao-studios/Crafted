import Foundation

/// One function of a unit: `static func <name>(<params>) throws -> <returns>`, and the rules it keeps.
public struct FunctionSpec: Codable, Sendable, Equatable {
    public var name: String
    public var params: [ParameterSpec]
    public var returns: String
    public var rules: [String]

    public init(name: String, params: [ParameterSpec] = [], returns: String, rules: [String] = []) {
        self.name = name; self.params = params; self.returns = returns; self.rules = rules
    }

    enum CodingKeys: String, CodingKey { case name, params, returns, rules }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decode(String.self, forKey: .name)
        params = try keyed.decodeIfPresent([ParameterSpec].self, forKey: .params) ?? []
        returns = try keyed.decode(String.self, forKey: .returns)
        rules = try keyed.decodeIfPresent([String].self, forKey: .rules) ?? []
    }

    /// `tip(bill: Double, percent: Double) throws -> Double`.
    public var signature: String {
        "\(name)(" + params.map(\.declaration).joined(separator: ", ") + ") throws -> \(returns)"
    }
}
