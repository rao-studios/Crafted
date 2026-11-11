import SwiftUI

/// Ambient's 8-pt status dot, in Craft's palette. Hollow means "nothing there yet";
/// `pulsing` breathes while that session's turn is running.
struct StatusDot: View {
    let color: Color
    var hollow = false
    var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    private var animates: Bool { pulsing && !reduceMotion }

    var body: some View {
        Group {
            if hollow {
                Circle().strokeBorder(color, lineWidth: 1)
            } else {
                Circle().fill(color)
            }
        }
        .frame(width: 8, height: 8)
        .opacity(animates && dim ? 0.35 : 1)
        .animation(animates ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default, value: dim)
        .onAppear { dim = animates }
        .onChange(of: animates) { _, on in dim = on }
    }
}
