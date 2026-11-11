import CraftedCore
import Foundation

/// One of the two models, as its card shows it: on disk or not, where, at which commit, and how much it takes.
public struct ModelStatus: Equatable, Sendable, Identifiable {
    public var kind: ModelKind
    public var installed: Bool
    /// The snapshot folder, when installed.
    public var path: String?
    /// The commit the copy was fetched at, when the Hub recorded one.
    public var commit: String?
    public var bytesOnDisk: Int64
    /// What a download still needs (0 when installed).
    public var remainingBytes: Int64

    public init(kind: ModelKind, installed: Bool, path: String? = nil, commit: String? = nil, bytesOnDisk: Int64 = 0,
                remainingBytes: Int64 = 0) {
        self.kind = kind; self.installed = installed; self.path = path; self.commit = commit
        self.bytesOnDisk = bytesOnDisk; self.remainingBytes = remainingBytes
    }

    public var id: ModelKind { kind }
    public var spec: ModelSpec { ModelCatalog.spec(kind) }
    /// Fetched at the commit Crafted pins.
    public var matchesPin: Bool { commit?.lowercased() == spec.revision.lowercased() }

    public static func missing(_ kind: ModelKind) -> ModelStatus {
        ModelStatus(kind: kind, installed: false, remainingBytes: ModelCatalog.spec(kind).downloadBytes)
    }
}

/// The download in flight.
public struct ModelDownload: Equatable, Sendable {
    public var kind: ModelKind
    public var fraction: Double

    public init(kind: ModelKind, fraction: Double) {
        self.kind = kind
        self.fraction = fraction
    }
}

/// What ModelService's ticketed entries answer.
public enum ModelServiceReply: Sendable {
    case catalog([ModelStatus])
    case removed(Int64)
}
