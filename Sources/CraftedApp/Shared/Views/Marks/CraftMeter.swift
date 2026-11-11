import SwiftUI

/// A thin capsule filled to a fraction: a source's share, an agent's part of a turn.
struct CraftMeter: View {
    let fraction: Double
    var tint: Color = .craftTint
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.craftFill)
                Capsule().fill(tint).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityValue("\(Int((min(max(fraction, 0), 1) * 100).rounded())) percent")
    }
}
