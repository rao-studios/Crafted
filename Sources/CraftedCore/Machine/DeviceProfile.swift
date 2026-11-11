//  WHAT: This Mac, as the onboarding's calibration reads it: the chip, the memory, and how much of it
//        Metal recommends a GPU workload keep resident.
//  IN:   sysctl (`machdep.cpu.brand_string`, `hw.memsize`) and the system Metal device.
//  OUT:  ModelTierRules (which coding models fit), the calibration step's figures.
//  PIN:  READ, NOTHING STARTED. Metal is asked for its device's numbers, never for a queue or a
//        library, and MLX is not touched: opening Craft never touches the GPU.

import Foundation
import Metal

public struct DeviceProfile: Sendable, Equatable {
    /// "Apple M4 Max".
    public var chip: String
    public var physicalBytes: Int
    /// Metal's recommended working set: what a model and its cache can hold on the GPU.
    public var gpuWorkingSetBytes: Int?

    public init(chip: String, physicalBytes: Int, gpuWorkingSetBytes: Int?) {
        self.chip = chip
        self.physicalBytes = physicalBytes
        self.gpuWorkingSetBytes = gpuWorkingSetBytes
    }

    public static func read() -> DeviceProfile {
        let device = MTLCreateSystemDefaultDevice()
        return DeviceProfile(chip: chipName() ?? device?.name ?? "This Mac",
                             physicalBytes: Int(ProcessInfo.processInfo.physicalMemory),
                             gpuWorkingSetBytes: device.map { Int(clamping: $0.recommendedMaxWorkingSetSize) })
    }

    /// Whole gigabytes, as Apple sells them: 128.
    public var memoryGB: Int { Int((Double(physicalBytes) / 1_073_741_824).rounded()) }

    static func chipName() -> String? {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else { return nil }
        let name = String(cString: bytes).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
