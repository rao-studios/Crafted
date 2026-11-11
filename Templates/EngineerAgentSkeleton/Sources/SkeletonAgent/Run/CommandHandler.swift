import Foundation

/// A command's handler: its arguments, already checked, and the kit in; what it made out, as products. A handler
/// calls the logic and returns products; it writes nothing itself, and reads only through the kit.
public protocol CommandHandler {
    associatedtype Arguments: Sendable
    static func run(_ arguments: Arguments, _ kit: CommandKit) async throws -> [Product]
}
