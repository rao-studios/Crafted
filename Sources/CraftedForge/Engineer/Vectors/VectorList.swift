import Foundation

/// A unit's vectors, as the coder answers them and the package holds them.
public struct VectorList: Codable, Sendable, Equatable {
    public var unit: String?
    public var vectors: [VectorSpec]
}
