//  WHAT: Whether Crafted can open: both models on disk and a role chosen. Read from disk and the preferences
//        store every time, never kept as a flag, so a model removed in Craft reopens the onboarding.
//  IN:   The model service's disk read, PreferencesService's role.
//  OUT:  The root's gate, the onboarding's Continue.

import Foundation

public struct ModelReadiness: Equatable, Sendable {
    public enum Gap: String, Equatable, Sendable { case vision, coder, role }

    public var gaps: [Gap]

    public init(gaps: [Gap]) { self.gaps = gaps }

    public var isReady: Bool { gaps.isEmpty }
    public var modelsReady: Bool { !gaps.contains(.vision) && !gaps.contains(.coder) }

    public static func evaluate(vision: Bool, coder: Bool, role: CraftedRole?) -> ModelReadiness {
        var gaps: [Gap] = []
        if !vision { gaps.append(.vision) }
        if !coder { gaps.append(.coder) }
        if role == nil { gaps.append(.role) }
        return ModelReadiness(gaps: gaps)
    }
}

/// Whether this Mac can run the models, as values: memory and disk.
public struct MachineFit: Equatable, Sendable {
    public var physicalGB: Int
    public var freeDiskBytes: Int64?

    public init(physicalGB: Int, freeDiskBytes: Int64?) {
        self.physicalGB = physicalGB
        self.freeDiskBytes = freeDiskBytes
    }

    /// The sentence that blocks a download, or nil when this Mac is enough.
    public func memoryShortfall(for spec: ModelSpec, allowLow: Bool = false) -> String? {
        guard !allowLow, physicalGB < spec.minimumMemoryGB else { return nil }
        return "\(spec.name) needs a Mac with \(spec.minimumMemoryGB) GB of memory. This Mac has \(physicalGB) GB."
    }

    /// The sentence that blocks a download for lack of disk: what is still needed plus 2 GB of room.
    public func diskShortfall(remainingBytes: Int64) -> String? {
        guard let free = freeDiskBytes else { return nil }
        let needed = remainingBytes + 2_000_000_000
        guard free < needed else { return nil }
        return String(format: "Needs %.1f GB free; this disk has %.1f GB.", Double(needed) / 1e9, Double(free) / 1e9)
    }
}
