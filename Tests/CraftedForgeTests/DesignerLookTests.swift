import CraftedCore
@testable import CraftedForge
import Foundation
import XCTest

/// The look's answer held to its rules: the palette's letters only, never a hex; closed lists; no typeface named.
final class DesignerLookTests: XCTestCase {
    let letters: Set<String> = ["A", "B", "C"]

    func testAnAnswerThatKeepsTheRulesPasses() {
        XCTAssertEqual(ObservationCheck.problems(DesignerSupport.look(background: "A", ink: "B", accent: ["C"]), letters: letters), [])
    }

    func testAHexIsRejectedWherePaletteLettersBelong() {
        let problems = ObservationCheck.problems(DesignerSupport.look(background: "#F7F7F2", ink: "B", accent: ["E30613"]), letters: letters)
        XCTAssertEqual(problems.count, 2, "\(problems)")
        XCTAssertTrue(problems.allSatisfy { $0.contains("never a hex") }, "\(problems)")
        XCTAssertTrue(ObservationCheck.problems(DesignerSupport.look(background: "Z", ink: "B"), letters: letters)
            .contains { $0.contains("not a letter of the palette") })
    }

    func testATypefaceNamedOrAValueOffItsListIsRejected() {
        var look = DesignerSupport.look(background: "A", ink: "B", notes: "Set in Helvetica Neue Bold, very tight.")
        look.layout.structure = "masonry"
        let problems = ObservationCheck.problems(look, letters: letters)
        XCTAssertTrue(problems.contains { $0.contains("names a typeface (helvetica)") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.hasPrefix("layout.structure is \"masonry\"") }, "\(problems)")
        look.notes = "unsure"
        look.layout.structure = "unsure"
        XCTAssertEqual(ObservationCheck.problems(look, letters: letters), [], "unsure is always allowed")
    }

    func testTheStructuredAskRepairsALookThatNamedAHex() async throws {
        let model = ScriptedModel(scripts: FileManager.default.temporaryDirectory)
        let bad = try JSONEncoder().encode(DesignerSupport.look(background: "#F7F7F2", ink: "B"))
        let good = try JSONEncoder().encode(DesignerSupport.look(background: "A", ink: "B"))
        await model.load(.init(format: nil, answers: [
            .init(purpose: "designer.look", match: nil, text: String(decoding: bad, as: UTF8.self), json: nil, once: true),
            .init(purpose: "designer.look", match: nil, text: String(decoding: good, as: UTF8.self), json: nil, once: nil)]))
        let ask = StructuredAsk(model: model, calls: nil)
        let look = try await ask.object(.vision, ModelPrompt(purpose: "designer.look", system: "s", user: "Piece: x.png"), as: Observation.self,
                                        budget: .look, image: .png(Data())) { ObservationCheck.problems($0, letters: self.letters) }
        XCTAssertEqual(look.colourRoles.background, "A", "the repair, told of the hex, answered with a letter")
    }
}
