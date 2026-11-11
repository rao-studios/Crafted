import Foundation

/// A vector's arguments, each made into the type its parameter takes.
struct VectorArguments {
    let values: [String: VectorJSON]

    /// The argument called `name` as a `T`; an optional parameter left out is nil.
    func value<T: Decodable>(_ name: String) throws -> T {
        let json = values[name] ?? .null
        do {
            return try VectorCoding.decoder.decode(T.self, from: VectorCoding.encoder.encode(json))
        } catch {
            throw VectorFailure.badArgument(name, "\(T.self)", json.description)
        }
    }
}
