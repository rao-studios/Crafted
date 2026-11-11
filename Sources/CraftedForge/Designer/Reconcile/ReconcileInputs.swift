import Foundation

/// Everything reconcile builds a style from: the run's artefacts, in the order of trust.
public struct ReconcileInputs: Sendable {
    public var name: String
    public var inventory: DesignInventory
    public var measures: DesignMeasures
    public var consensus: LookConsensus
    public var rights: RightsOutcome
    public var synthesis: SynthesisResult
    public var fallbacks: FallbackFaces

    public init(name: String, inventory: DesignInventory, measures: DesignMeasures, consensus: LookConsensus, rights: RightsOutcome,
                synthesis: SynthesisResult, fallbacks: FallbackFaces) {
        self.name = name; self.inventory = inventory; self.measures = measures; self.consensus = consensus; self.rights = rights
        self.synthesis = synthesis; self.fallbacks = fallbacks
    }
}

/// A style and the files it ships beside it: each from a path in the dropped folder to a path under Style/.
public struct ReconciledStyle: Codable, Sendable, Equatable {
    public struct Asset: Codable, Sendable, Equatable {
        /// Relative to the dropped folder.
        public var from: String
        /// Relative to the package's Style folder: "Fonts/x.ttf", "Marks/mark.svg".
        public var to: String
    }

    public var style: DesignerStyle
    public var assets: [Asset]
}
