//  WHAT: The blooms waiting on a painting's unpainted paper: each scene's three pools of pigment, laid where the wash
//        arrives late, breathing slowly, and gone before the wash reaches them.
//  IN:   The scene, the painting's size, the wash's progress, whether they may move.
//  OUT:  The blooms, laid under the painting's layers (the far layer covers them once painted).
//  PIN:  A bloom fades over the 0.12 of progress before its region's band begins (WatercolourScene.blooms), so the
//        front never meets one; under Reduce Motion they lie still.

import SwiftUI

struct SceneBlooms: View {
    let scene: WatercolourScene
    let size: CGSize
    let progress: Double
    let breathing: Bool
    @State private var inhaled = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(scene.blooms.enumerated()), id: \.offset) { index, bloom in
                let fade = min(max((bloom.arrives - progress) / 0.12, 0), 1)
                if fade > 0 {
                    BloomPool(tone: bloom.tone, opacity: 0.38 * fade * (breathing && !inhaled ? 0.82 : 1))
                        .frame(width: size.width * bloom.width)
                        .rotationEffect(.degrees(bloom.turn))
                        .scaleEffect(breathing && inhaled ? 1.04 : 0.97)
                        .position(x: size.width * bloom.center.x, y: size.height * bloom.center.y)
                        .animation(
                            breathing ? .easeInOut(duration: 6.5 + Double(index) * 0.8).repeatForever(autoreverses: true) : .default,
                            value: inhaled
                        )
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear { inhaled = breathing }
        .onChange(of: breathing) { _, on in inhaled = on }
    }
}
