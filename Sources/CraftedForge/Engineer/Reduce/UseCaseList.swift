import Foundation

/// The use cases, as the model answers them.
public struct UseCaseList: Codable, Sendable, Equatable {
    public var usecases: [UseCase]
}
