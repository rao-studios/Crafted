import Foundation

/// A source file taken into the package as it is: `source` relative to the dropped folder, `name` as the package
/// holds it (a resource's name under Resources/, a lifted file's name under Lifted/).
public struct CarriedFile: Codable, Sendable, Equatable, Hashable {
    public var source: String
    public var name: String

    public init(source: String, name: String) { self.source = source; self.name = name }
}
