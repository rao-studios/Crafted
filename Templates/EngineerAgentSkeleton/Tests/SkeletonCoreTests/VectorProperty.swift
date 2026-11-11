import Foundation

/// What must hold of a result when its exact value is not the point.
///
/// `equals` `approx` (value), `roundTrip` (via, into, back), `monotonic` (argument, values, direction), `sumsTo`
/// (value), `inRange` (min, max), `deterministic`, `throws`, `permutationOf` (value), `lengthIs` (value), `matches`
/// (pattern). `path` reads inside a result object ("tip").
struct VectorProperty: Decodable {
    var kind: String
    var value: VectorJSON?
    var path: String?
    var via: String?
    var into: String?
    var back: String?
    var argument: String?
    var values: [VectorJSON]?
    var direction: String?
    var min: Double?
    var max: Double?
    var pattern: String?
}
