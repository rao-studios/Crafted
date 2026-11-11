import CraftedCore
import CraftedForge
import Granite
import SwiftUI

/// The person's answer to the run's question, as the page routes it.
struct DecisionReply: Equatable {
    let decision: String
    let answer: DecisionAnswer
}

/// A question only the person can answer (which fonts may ship, which picture is their mark, a unit that would not
/// port): the options, the default chosen, words when it takes them, and Answer. The run waits on it.
struct DecisionCard: View {
    let decision: Decision
    @Environment(\.graniteBubble) private var bubble
    @State private var option: String?
    @State private var text = ""

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer3) {
                HStack(spacing: .layer2) {
                    Image(systemName: "questionmark.circle").font(.craftGlyph(.heading)).foregroundStyle(Color.craftTint)
                    Text(decision.question).craftType(.heading).foregroundStyle(Color.craftInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(decision.detail.enumerated()), id: \.offset) { _, line in
                    Text(line).craftType(.caption).foregroundStyle(Color.craftInkSoft).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(decision.options) { candidate in
                    Button { option = candidate.id } label: {
                        HStack(alignment: .top, spacing: .layer2) {
                            Image(systemName: chosen == candidate.id ? "largecircle.fill.circle" : "circle")
                                .font(.craftGlyph(.label))
                                .foregroundStyle(chosen == candidate.id ? Color.craftTint : Color.craftInkDim)
                            VStack(alignment: .leading, spacing: .hairline) {
                                Text(candidate.title).craftType(.labelStrong).foregroundStyle(Color.craftInk)
                                if let detail = candidate.detail {
                                    Text(detail).craftType(.caption).foregroundStyle(Color.craftInkDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if decision.takesText {
                    CraftTextField(placeholder: "In your words (optional)", text: $text)
                }
                HStack {
                    Button("Answer") { answer() }.buttonStyle(.craft).keyboardShortcut(.defaultAction)
                    Text("The run waits for this; it is kept, so it is never asked again.")
                        .craftType(.caption).foregroundStyle(Color.craftInkDim)
                }
            }
        }
    }

    private var chosen: String { option ?? decision.defaultOption }

    private func answer() {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        bubble(.decisionAnswer, DecisionReply(decision: decision.id,
                                              answer: DecisionAnswer(option: chosen, text: words.isEmpty ? nil : words)))
    }
}

/// The run stopped: why, in its own words, and Resume (it picks up from its ledger).
struct FailureCard: View {
    let reason: String
    let resumable: Bool
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer3) {
                HStack(spacing: .layer2) {
                    Image(systemName: "exclamationmark.triangle").font(.craftGlyph(.heading)).foregroundStyle(Color.craftError)
                    Text("The run stopped").craftType(.heading).foregroundStyle(Color.craftInk)
                }
                Text(reason).craftType(.label).foregroundStyle(Color.craftInkSoft)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                HStack(spacing: .layer2) {
                    if resumable { Button("Resume") { resume() }.buttonStyle(.craft) }
                    Button("Show in Finder") { finder() }.buttonStyle(.craftQuiet)
                        .help("The run's folder: its events.jsonl says what happened, step by step.")
                }
            }
        }
    }

    private func resume() { bubble(.failureResume) }
    private func finder() { bubble(.failureFinder) }
}

/// The listing form over a live run, with a thin strip of the run's progress on top: the run goes on while it is open.
struct ListingPanel: View {
    let id: String
    let fraction: Double
    let live: Bool
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(spacing: 0) {
            if live { CraftMeter(fraction: fraction, height: 2) }
            HStack {
                Text(live ? "Listing & icon · the run goes on" : "Listing & icon").craftType(.captionStrong).foregroundStyle(Color.craftInkDim)
                Spacer()
                Button { close() } label: { Image(systemName: "xmark").font(.craftGlyph(.caption)) }
                    .buttonStyle(.plain).foregroundStyle(Color.craftInkDim).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, .layer4)
            .padding(.vertical, .layer2)
            Divider().overlay(Color.craftBorder)
            Listing(id: id, mode: .panel)
        }
        .frame(width: CraftLayout.Run.panelWidth)
        .frame(maxHeight: .infinity)
        .background(Color.craftBG)
        .overlay(alignment: .leading) { Rectangle().fill(Color.craftBorder).frame(width: 1) }
        .shadow(color: Color.craftShadow, radius: 12, x: -2)
    }

    private func close() { bubble(.listingPanelClose) }
}

extension GraniteBubble.Name {
    static let decisionAnswer: Self = "DecisionCard.answer"
    static let failureResume: Self = "FailureCard.resume"
    static let failureFinder: Self = "FailureCard.finder"
    static let listingPanelClose: Self = "ListingPanel.close"
}
