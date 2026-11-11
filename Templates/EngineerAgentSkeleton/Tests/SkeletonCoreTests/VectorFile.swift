import Foundation

/// A unit's vectors, as Vectors/<Unit>.vectors.json holds them.
struct VectorFile: Decodable {
    var unit: String
    var vectors: [Vector]
}
