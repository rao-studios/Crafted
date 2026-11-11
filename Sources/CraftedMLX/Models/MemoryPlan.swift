//  WHAT: What this Mac can give a model: its memory against each spec's floor, the disk free in the model home, and
//        the GPU limits a load sets.
//  IN:   DeviceProfile (sysctl, Metal's recommended working set, read without starting anything); the volume's
//        free capacity.
//  OUT:  ModelService (MachineFit for the cards' shortfall lines), MLXModelRuntime (the limits before a load).
//  PIN:  ONE RESIDENT. The plan sizes for one model at a time: the coder's 27.5 GB of weights, its cache, and the
//        rest of the Mac. Vision and coder are never resident together (ModelCatalog's note).

import CraftedCore
import Foundation

public struct MemoryPlan: Sendable, Equatable {
    public var physicalBytes: Int
    public var gpuWorkingSetBytes: Int?

    public init(physicalBytes: Int, gpuWorkingSetBytes: Int?) {
        self.physicalBytes = physicalBytes
        self.gpuWorkingSetBytes = gpuWorkingSetBytes
    }

    public static func read() -> MemoryPlan {
        let profile = DeviceProfile.read()
        return MemoryPlan(physicalBytes: profile.physicalBytes, gpuWorkingSetBytes: profile.gpuWorkingSetBytes)
    }

    public var physicalGB: Int { Int((Double(physicalBytes) / 1_073_741_824).rounded()) }

    /// `CRAFTED_ALLOW_LOW_MEMORY=1` lets a smaller Mac download and run anyway (development).
    public static var allowsLowMemory: Bool { ProcessInfo.processInfo.environment["CRAFTED_ALLOW_LOW_MEMORY"] == "1" }

    public func fits(_ spec: ModelSpec) -> Bool { Self.allowsLowMemory || physicalGB >= spec.minimumMemoryGB }

    /// The values the cards' shortfall lines read, with the free disk where `home` lives.
    public func machineFit(home: ModelHome = .standard) -> MachineFit {
        MachineFit(physicalGB: physicalGB, freeDiskBytes: Self.freeDiskBytes(at: home.huggingFace))
    }

    /// The GPU limits a load of `spec` sets: a memory line at the working set Metal recommends (or three quarters of
    /// the Mac), and a buffer cache of a sixteenth of it, so freed buffers go back to the Mac rather than pile up.
    public func limits(for spec: ModelSpec) -> (cacheMB: Int, memoryMB: Int) {
        let working = gpuWorkingSetBytes ?? physicalBytes / 4 * 3
        let memoryMB = max(working / 1_048_576, Int(spec.downloadBytes / 1_048_576) + 2_048)
        return (cacheMB: max(512, memoryMB / 16), memoryMB: memoryMB)
    }

    /// Free bytes on the volume holding `url` (or its nearest existing parent), for important use.
    public static func freeDiskBytes(at url: URL) -> Int64? {
        var probe = url
        let fm = FileManager.default
        while !fm.fileExists(atPath: probe.path), probe.pathComponents.count > 1 { probe.deleteLastPathComponent() }
        let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        if let important = values?.volumeAvailableCapacityForImportantUsage, important > 0 { return important }
        return values?.volumeAvailableCapacity.map(Int64.init)
    }
}
