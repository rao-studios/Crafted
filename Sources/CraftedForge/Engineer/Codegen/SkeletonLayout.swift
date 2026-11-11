//  WHAT: Where each part of a port lives in EngineerAgentSkeleton, by the template's own names (the assembler maps them
//        to the agent's): generated surface and contracts, the port's slot bodies, carried and lifted files, vectors
//        and canonical calls.
//  PIN:  THE PORT OWNS ITS FOLDERS. Every file in `portFolders` comes from the plan; a template file there that the
//        plan does not supply (the sample tip calculator) is left out of an assembly.

import Foundation

public enum SkeletonLayout {
    public static let coreTarget = "SkeletonCore"
    public static let agentTarget = "SkeletonAgent"
    public static let coreTests = "SkeletonCoreTests"
    public static let agentTests = "SkeletonAgentTests"

    static let core = "Sources/SkeletonCore"
    static let agent = "Sources/SkeletonAgent"

    public static func contract(_ unit: String) -> String { "\(core)/Contracts/\(unit)Contract.swift" }
    public static func logic(_ unit: String) -> String { "\(core)/Logic/\(unit).swift" }
    public static func domain(_ type: String) -> String { "\(core)/Domain/\(type).swift" }
    public static func resource(_ name: String) -> String { "\(core)/Resources/\(name)" }
    public static func lifted(_ name: String) -> String { "\(core)/Lifted/\(name)" }

    public static let commandEnum = "\(agent)/Surface/Command.swift"
    public static let input = "\(agent)/Surface/AgentInput.swift"
    public static let dispatch = "\(agent)/Surface/Dispatch.swift"
    public static let surface = "\(agent)/Surface/Surface.swift"
    public static func choice(_ field: String) -> String { "\(agent)/Surface/\(SwiftText.pascal(field))Choice.swift" }
    public static func arguments(_ command: String) -> String { "\(agent)/Surface/\(SwiftText.pascal(command))Arguments.swift" }
    public static func handler(_ command: String) -> String { "\(agent)/Handlers/\(SwiftText.pascal(command))Handler.swift" }

    public static let vectorCalls = "Tests/SkeletonCoreTests/Generated/VectorCalls.swift"
    public static let vectorTests = "Tests/SkeletonCoreTests/Generated/VectorTests.swift"
    public static func vectors(_ unit: String) -> String { "Tests/SkeletonCoreTests/Vectors/\(unit).vectors.json" }
    public static let expectedSurface = "Tests/SkeletonAgentTests/Generated/ExpectedSurface.swift"
    public static let callTests = "Tests/SkeletonAgentTests/Generated/CallTests.swift"
    public static func call(_ command: String) -> String { "Tests/SkeletonAgentTests/Calls/\(command).call.json" }

    /// The folders a port fills; the template's own files in them are its sample.
    public static let portFolders = [
        "\(core)/Contracts", "\(core)/Domain", "\(core)/Logic", "\(core)/Lifted", "\(core)/Resources",
        "\(agent)/Surface", "\(agent)/Handlers",
        "Tests/SkeletonCoreTests/Generated", "Tests/SkeletonCoreTests/Vectors",
        "Tests/SkeletonAgentTests/Generated", "Tests/SkeletonAgentTests/Calls",
    ]

    /// Files in the port's folders that are the template's own, kept whatever the plan.
    public static let fixedInPortFolders: Swift.Set<String> = ["\(core)/Resources/RESOURCES.md"]

    /// The test filter that runs one unit's vectors (`<Core>Tests.VectorTests/testTipMath`), by the template's names.
    public static func vectorFilter(_ unit: String) -> String { "\(coreTests).VectorTests/test\(unit)" }

    /// The test filter that runs one command's canonical call.
    public static func callFilter(_ command: String) -> String { "\(agentTests).CallTests/test\(SwiftText.pascal(command))Call" }
}
