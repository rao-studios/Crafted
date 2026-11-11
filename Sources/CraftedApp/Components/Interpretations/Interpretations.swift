//  WHAT: Engineer: three ways the project could become an agent (whole, core, material), as three cards: name, word,
//        summary, its commands, what goes to Canvas and what is handed on, the files it ports, what it leaves out and
//        why, confidence and effort. Choose one, or none of these with a steer in the person's words.
//  IN:   ForgeService's live run (its cards and round).
//  OUT:  ForgeService (choose, steer).
//  PIN:  The painting holds where it stopped, as a band above the cards; one bloom per card (sky, brass, clay).

import CraftedCore
import CraftedForge
import CraftedRuntime
import Granite
import SwiftUI

struct Interpretations: GraniteComponent {
    @Command var center: Center
    @Relay var forge: ForgeService
    @Relay var library: LibraryService

    @StateObject var clock = RelayClock([.on(ForgeService.self)])

    let id: String

    init(id: String) {
        self.id = id
    }
}

extension Interpretations {
    struct Center: GraniteCenter {
        struct State: GraniteState {
            /// "None of these": the person's words for the next three.
            var steer = ""
        }

        @Store var state: State
    }
}

extension Interpretations {
    var view: some View {
        let run = forge.state.live(id)
        let cards = run?.cards ?? []
        let title = library.state.generation(id)?.title ?? "Your project"
        return ScrollView {
            VStack(alignment: .leading, spacing: .layer4) {
                PageBar(title: title, subtitle: "Three agents it could become\((run?.round ?? 0) > 0 ? " · round \((run?.round ?? 0) + 1)" : "")") {
                    Button("Cancel") { forge.cancel(id) }.buttonStyle(.craftQuiet)
                }
                PaperLeaf(cornerRadius: 12) {
                    ScenePainting(scene: .gardens, progress: run?.fraction ?? 0, animated: false)
                }
                .frame(height: 110)
                Text("Each is a different agent made from the same verified reading of your project. Pick the one to port; the others are not lost: steer for three more.")
                    .craftType(.label).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: .layer4) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        InterpretationCardView(card: card, index: index, tone: Self.tone(index))
                    }
                }
                SteerCard(text: center.$state.binding.steer)
            }
            .padding(.layer5)
            .padding(.top, .layer4)
        }
        .onBubble {
            On(.interpretationChoose, Int.self) { forge.choose($0, in: id) }
            On(.interpretationSteer) {
                let words = state.steer.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !words.isEmpty else { return }
                forge.steer(words, in: id)
                _state.steer.wrappedValue = ""
            }
            On(.pageBarBack) { CraftedAppRoot.shared.showLibrary() }
        }
    }

    static func tone(_ index: Int) -> BloomPool.Tone {
        [BloomPool.Tone.sky, .brass, .clay][index % 3]
    }
}
