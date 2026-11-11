import CraftedCore
@testable import CraftedForge
import Foundation
import XCTest

/// Reconcile by trust order: declared over measured over observed over inferred; contrast brought up by lightness and
/// logged; a style held to what the kit needs.
final class DesignerReconcileTests: XCTestCase {
    /// A light folder of three colours (paper A, ink B, red C) and a fourth no piece uses (D).
    private func measures(declared: DeclaredStyle = DeclaredStyle(), roles: [String: [String: String]] = ["background": ["light": "A"], "ink": ["light": "B"]]) -> DesignMeasures {
        let palette = [("A", "#F7F7F2", 0.7), ("B", "#111111", 0.2), ("C", "#E30613", 0.08), ("D", "#3366CC", 0.02)].map { id, hex, weight in
            DesignMeasures.Colour(id: id, hex: hex, lab: OKLab(hex: hex)!, name: id, weight: weight, pieces: 1, source: "measured", declaredAs: [])
        }
        return DesignMeasures(palette: palette, grounds: ["light": 2], pieces: [:], margins: [0.08, 0.08, 0.08, 0.08], ink: 0.2, fonts: [],
                              declared: declared, words: [], credit: nil, roles: roles)
    }

    private func inputs(_ measures: DesignMeasures, looks: [Observation], colour: ColourAnswer? = nil) -> ReconcileInputs {
        let inventory = DesignInventory(entries: [], pieces: [], sampled: [], fonts: [], declared: [], texts: [], marks: [], unopenable: [])
        return ReconcileInputs(name: "Test", inventory: inventory, measures: measures,
                               consensus: LookConsensus(looks: looks, grounds: looks.map { _ in "light" }),
                               rights: RightsOutcome(fonts: [], mark: nil, designer: "Test Designer", url: nil, notes: []),
                               synthesis: SynthesisResult(colour: colour), fallbacks: FallbackFaces.load())
    }

    func testTheTrustOrderIsDeclaredMeasuredObservedInferred() {
        XCTAssertEqual(TrustOrder.pick(declared: nil, measured: "A", observed: "B", inferred: "C")?.value, "A")
        XCTAssertEqual(TrustOrder.pick(declared: nil, measured: "A", observed: "B", inferred: "C")?.source, .measured)
        XCTAssertEqual(TrustOrder.pick(declared: "D", measured: "A", observed: "B", inferred: "C")?.source, .declared)
        XCTAssertEqual(TrustOrder.pick(declared: nil as String?, measured: nil, observed: "B", inferred: "C")?.value, "B")
        XCTAssertEqual(TrustOrder.pick(declared: nil as String?, measured: nil, observed: nil, inferred: "C")?.source, .inferred)
    }

    func testMeasuredRolesWinOverWhatWasSeenAndWhatWasInferred() {
        // Measured: background A, ink B. Seen: background D, ink C. Inferred: background C, ink D.
        let looks = [DesignerSupport.look(background: "D", ink: "C"), DesignerSupport.look(background: "D", ink: "C")]
        let colour = ColourAnswer(roles: ["background": .init(light: "C", dark: "B"), "ink": .init(light: "D", dark: "A")], gradients: nil, usage: nil)
        let style = StyleReconciler.reconcile(inputs(measures(), looks: looks, colour: colour)).style
        XCTAssertEqual(style.colour.roles["background"]?.light, "A", "measured beats seen and inferred")
        XCTAssertEqual(style.colour.roles["ink"]?.light, "B")
        XCTAssertTrue(style.provenance.decisions.contains { $0.contains("background A (measured)") }, "\(style.provenance.decisions)")
        // What nothing measured, the look decides over the model: the accent.
        let seenAccent = [DesignerSupport.look(background: "A", ink: "B", accent: ["C"])]
        let inferredAccent = ColourAnswer(roles: ["accent": .init(light: "D", dark: "D")], gradients: nil, usage: nil)
        XCTAssertEqual(StyleReconciler.reconcile(inputs(measures(), looks: seenAccent, colour: inferredAccent)).style.colour.roles["accent"]?.light, "C")
    }

    func testADeclaredRoleWinsOverMeasurement() {
        var declared = DeclaredStyle()
        declared.add(colour: "#3366CC", name: "--color-background", source: "tokens.css")
        let style = StyleReconciler.reconcile(inputs(measures(declared: declared), looks: [])).style
        XCTAssertEqual(style.colour.roles["background"]?.light, "D", "the designer's word over the measure")
    }

    func testContrastIsBroughtUpByLightnessAndLogged() {
        XCTAssertEqual(Contrast.ratio("#000000", "#FFFFFF"), 21, accuracy: 0.01)
        let grey = "#9A9A9A"
        XCTAssertLessThan(Contrast.ratio(grey, "#FFFFFF"), 4.5)
        let fixed = Contrast.adjusted(grey, against: "#FFFFFF", target: 4.5)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(fixed, "#FFFFFF"), 4.5)
        XCTAssertLessThan(OKLab(hex: fixed)!.l, OKLab(hex: grey)!.l, "darker on a light ground")
        XCTAssertLessThan(Contrast.ratio(fixed, "#FFFFFF"), 5.2, "the least change that reaches it")
        let gold = Contrast.adjusted("#7A6230", against: "#1A0F1F", target: 4.5)
        XCTAssertGreaterThan(OKLab(hex: gold)!.l, OKLab(hex: "#7A6230")!.l, "lighter on a dark ground")
        XCTAssertGreaterThan(OKLab(hex: gold)!.chroma, 0.03, "still gold, not grey")
        // In a style: a muted ink that does not read is adjusted, and the style says so.
        let looks = [DesignerSupport.look(background: "A", ink: "B")]
        let colour = ColourAnswer(roles: ["inkMuted": .init(light: "D", dark: "D")], gradients: nil, usage: nil)
        var m = measures()
        m.palette[3] = DesignMeasures.Colour(id: "D", hex: "#B8B8B8", lab: OKLab(hex: "#B8B8B8")!, name: "pale grey", weight: 0.02, pieces: 1, source: "measured", declaredAs: [])
        let reconciled = StyleReconciler.reconcile(inputs(m, looks: looks, colour: colour))
        XCTAssertEqual(StyleValidator.problems(reconciled), [], "every role reads once reconciled")
        let muted = reconciled.style.colour.hex("inkMuted", "light")!
        XCTAssertNotEqual(muted, "#B8B8B8")
        XCTAssertTrue(reconciled.style.colour.palette.contains { $0.hex == muted && $0.source == "adjusted" })
        XCTAssertTrue(reconciled.style.provenance.decisions.contains { $0.hasPrefix("inkMuted D #B8B8B8 on light background") }, "\(reconciled.style.provenance.decisions)")
    }

    func testEveryFormatGetsAnEngine() {
        let style = StyleReconciler.reconcile(inputs(measures(), looks: [])).style
        let covered = Set(style.layout.archetypes.flatMap { $0.for.isEmpty ? DesignerStyle.formats : $0.for })
        XCTAssertEqual(covered, Set(DesignerStyle.formats))
    }
}
