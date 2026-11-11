import CraftedCore
import CraftedForge
import Granite
import SwiftUI

/// One interpretation, whole: what it is called and does, its commands with their arguments and what they make, what
/// goes to Canvas or is handed on, the source files it ports, what it leaves out, and how sure and how big it is.
struct InterpretationCardView: View {
    let card: InterpretationCard
    let index: Int
    let tone: BloomPool.Tone
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: .layer3) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: .layer1) {
                    CraftBadge(text: card.archetype.rawValue, color: .craftInkSoft)
                    Text(card.name).craftType(.title).foregroundStyle(Color.craftInk).fixedSize(horizontal: false, vertical: true)
                    Text("@" + card.word).craftType(.identifier).foregroundStyle(Color.craftInkDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                BloomPool(tone: tone, opacity: 0.35).frame(width: 70, height: 70).allowsHitTesting(false)
            }
            Text(card.summary).craftType(.body).foregroundStyle(Color.craftInkSoft).fixedSize(horizontal: false, vertical: true)
            section("Commands") {
                ForEach(card.commands, id: \.self) { command in
                    VStack(alignment: .leading, spacing: .hairline) {
                        Text(command.name).craftType(.code).foregroundStyle(Color.craftInk)
                        Text(command.summary).craftType(.caption).foregroundStyle(Color.craftInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        if !command.args.isEmpty {
                            Text(command.args.map { "\($0.name): \($0.type)\($0.required ? "" : "?")" }.joined(separator: ", "))
                                .craftType(.codeSmall).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
                        }
                        if !command.produces.isEmpty {
                            Text("→ " + command.produces.map { "\($0.what) (\($0.channel))" }.joined(separator: "; "))
                                .craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if !card.canvas.isEmpty || !card.handsOff.isEmpty {
                section("Canvas and hand-offs") {
                    ForEach(card.canvas + card.handsOff, id: \.self) { line in bullet(line) }
                }
            }
            if !card.ports.isEmpty {
                section("Ports") {
                    ForEach(card.ports.prefix(8), id: \.self) { port in
                        Text("\(port.how) · \(port.path)").craftType(.codeSmall).foregroundStyle(Color.craftInkSoft)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    if card.ports.count > 8 {
                        Text("and \(card.ports.count - 8) more").craftType(.caption).foregroundStyle(Color.craftInkDim)
                    }
                }
            }
            if !card.leavesOut.isEmpty {
                section("Leaves out") {
                    ForEach(card.leavesOut, id: \.self) { left in bullet("\(left.what): \(left.why)") }
                }
            }
            FlowLayout(spacing: .layer5, lineSpacing: .layer3) {
                CraftStat(value: "\(Int((card.confidence * 100).rounded()))%", label: "Confidence")
                CraftStat(value: card.risk.capitalized, label: "Risk")
                if let minutes = effortMinutes { CraftStat(value: minutes, label: "Effort") }
            }
            if !card.basis.isEmpty {
                Text(card.basis).craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Choose this one") { choose() }
                .buttonStyle(.craft)
                .accessibilityIdentifier("interpretations.choose.\(index)")
        }
        .padding(.layer4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: CraftRadius.card, style: .continuous).fill(Color.craftRaised))
        .overlay(RoundedRectangle(cornerRadius: CraftRadius.card, style: .continuous).strokeBorder(Color.craftBorder))
    }

    private var effortMinutes: String? {
        guard let low = card.minutes.first else { return nil }
        if let high = card.minutes.last, high != low { return "\(low)–\(high) min" }
        return "\(low) min"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: .layer1) {
            SectionLabel(title)
            content()
        }
    }

    private func bullet(_ text: String) -> some View {
        Text("· " + text).craftType(.caption).foregroundStyle(Color.craftInkSoft).fixedSize(horizontal: false, vertical: true)
    }

    private func choose() { bubble(.interpretationChoose, index) }
}

/// None of these: the person's words steer the next three.
struct SteerCard: View {
    @Binding var text: String
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer2) {
                SectionLabel("None of these")
                Text("Say what you would rather it became; Crafted reads the same project again with your words and offers three more.")
                    .craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: .layer2) {
                    CraftTextField(placeholder: "An agent that…", text: $text)
                        .onSubmit { steer() }
                    Button("Steer") { steer() }
                        .buttonStyle(.craftQuiet)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func steer() { bubble(.interpretationSteer) }
}

extension GraniteBubble.Name {
    static let interpretationChoose: Self = "InterpretationCardView.choose"
    static let interpretationSteer: Self = "SteerCard.steer"
}
