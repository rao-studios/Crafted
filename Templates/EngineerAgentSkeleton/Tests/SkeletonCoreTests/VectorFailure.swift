import Foundation

/// Why a vector could not be run: no such function, an argument of the wrong shape, no vectors file.
enum VectorFailure: Error, CustomStringConvertible {
    case unknownFunction(String)
    case badArgument(String, String, String)
    case missingFile(String)

    var description: String {
        switch self {
        case .unknownFunction(let name): return "no contract function \(name)"
        case .badArgument(let name, let type, let json): return "argument \(name) (\(json)) is not a \(type)"
        case .missingFile(let path): return "no vectors at \(path)"
        }
    }
}
