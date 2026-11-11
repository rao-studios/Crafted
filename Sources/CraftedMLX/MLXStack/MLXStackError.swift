import Darwin
import Foundation
import FrigateBridge
import MLX
import MLXLLM
import MLXLMCommon

public enum MLXStackError: Error, CustomStringConvertible {
    case metallibMissing(String)

    public var description: String {
        switch self {
        case .metallibMissing(let hint): return hint
        }
    }
}
