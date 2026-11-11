import SwiftUI

/// The onboarding's steps across the top: done, here, to come.
struct StepBar: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: .layer2) {
            ForEach(OnboardingStep.allCases) { step in
                HStack(spacing: .snug) {
                    Image(systemName: step.rawValue < current.rawValue ? "checkmark.circle.fill" : step.symbol)
                        .font(.craftGlyph(.caption, weight: .semibold))
                    Text(step.title).craftType(step == current ? .captionStrong : .caption).lineLimit(1)
                }
                // Every step's name whole; the rules between them give way.
                .fixedSize()
                .foregroundStyle(step == current ? Color.craftInk : step.rawValue < current.rawValue ? Color.craftInkSoft : Color.craftInkFaint)
                if step != OnboardingStep.allCases.last {
                    Rectangle().fill(Color.craftBorder).frame(height: 1).frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(current.rawValue + 1) of \(OnboardingStep.allCases.count): \(current.title)")
    }
}
