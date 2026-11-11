//  WHAT: One of the Lyon watercolours, filling its frame: the far layer, the near layer, the fog over them, on paper.
//        Given a progress, it paints itself in: the wash crosses the paper in the scene's order (sky, then river and
//        city, then the woods, the basilica and its gilded Virgin last), blooms of pigment wait on the paper ahead
//        of it, and the fog and the near layer come in at the end.
//  IN:   The scene; progress 0…1, or nil for the finished painting; whether it may move (fog drift, the wet edge's
//        shimmer, the blooms' breathing).
//  OUT:  The painting, cropped about the scene's focus (SceneBox).
//  PIN:  THE WASH IS THE SHADER (Shaders/Watercolour.metal) over the far and near layers, reading the scene's arrival
//        map. Reduce Motion, or a shader or arrival map that did not load, gives a stepped crossfade instead:
//        quarter steps, eased, no shimmer, no drift, no breathing.
//  PIN:  CHEAP: the wash redraws at most 20 times a second, only while it is washing, animated, and its window can be
//        seen. A finished painting has no timeline; its fog drifts by one long SwiftUI animation (the site's ±2.2%
//        over 46 s, ease-in-out, back and forth).
//  PIN:  Progress 1 is drawn without the shader: the wash's last frame is the painting itself, so nothing jumps.
//  PIN:  A scene not yet decoded shows paper while it decodes off the main thread (WatercolourArt.preload), then
//        fades in: about 20 MB of WebP would otherwise stall the first frame.

import SwiftUI

struct ScenePainting: View {
    private let scene: WatercolourScene
    private let progress: Double?
    private let animated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var windowVisible = true
    @State private var drifting = false
    @State private var decoded = false

    init(scene: WatercolourScene, progress: Double? = nil, animated: Bool = true) {
        self.scene = scene
        self.progress = progress
        self.animated = animated
    }

    /// Where the wash is, clamped; nil once it is whole.
    private var wash: Double? {
        guard let progress, progress.isFinite else { return progress == nil ? nil : 0 }
        return progress >= 1 ? nil : max(progress, 0)
    }

    private var moving: Bool { animated && !reduceMotion }

    /// The arrival map, when the wash is drawn by the shader; nil when it crossfades or is whole.
    private var arrival: CGImage? {
        guard wash != nil, !reduceMotion, WatercolourShader.isAvailable else { return nil }
        return WatercolourArt.arrival(scene)
    }

    var body: some View {
        GeometryReader { proxy in
            let box = SceneBox(frame: proxy.size, focus: (scene.focus.x, scene.focus.y))
            ZStack(alignment: .topLeading) {
                WatercolourPalette.paper
                if decoded || WatercolourArt.isDecoded(scene) {
                    canvas(box)
                        .frame(width: box.fill.width, height: box.fill.height, alignment: .topLeading)
                        .offset(x: box.origin.x, y: box.origin.y)
                        .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .background { WindowVisibilityReader(isVisible: $windowVisible) }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: scene) {
            if !WatercolourArt.isDecoded(scene) {
                let scene = scene
                await Task.detached(priority: .userInitiated) { WatercolourArt.preload(scene) }.value
            }
            withAnimation(.easeOut(duration: 0.35)) { decoded = true }
        }
        .onAppear { drifting = moving }
        .onChange(of: moving) { _, on in drifting = on }
    }

    @ViewBuilder
    private func canvas(_ box: SceneBox) -> some View {
        if let arrival {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !moving || !windowVisible)) { context in
                layers(box, arrival: arrival, time: Self.clock(context.date))
            }
        } else {
            layers(box, arrival: nil, time: 0)
        }
    }

    private func layers(_ box: SceneBox, arrival: CGImage?, time: Double) -> some View {
        let fill = box.fill
        let p = wash ?? 1
        let shading = arrival != nil
        let shader = arrival.flatMap { WatercolourShader.wash(size: fill, progress: p, time: time, arrival: $0) }
        // The near layer and the fog come in at the end; a crossfade steps everything by quarters.
        let near = Self.ramp(p, from: 0.6, to: 0.95)
        let fog = Self.ramp(p, from: 0.75, to: 1)
        let steps = [Self.step(p), Self.step(near), Self.step(fog)]
        return ZStack(alignment: .topLeading) {
            if wash != nil {
                SceneBlooms(scene: scene, size: fill, progress: p, breathing: moving)
            }
            WashLayer(image: WatercolourArt.layer(scene, .far), size: fill, wash: shader)
                .opacity(shading ? 1 : steps[0])
            WashLayer(image: WatercolourArt.layer(scene, .near), size: fill, wash: shader)
                .opacity(shading ? near : steps[1])
            WashLayer(image: WatercolourArt.layer(scene, .fog), size: box.fog, wash: nil)
                .offset(x: -(box.fog.width - fill.width) / 2 + drift(box), y: fill.height - box.fog.height)
                .opacity(shading ? fog : steps[2])
                .animation(moving ? .easeInOut(duration: 46).repeatForever(autoreverses: true) : .default, value: drifting)
        }
        .animation(shading ? nil : .easeInOut(duration: 0.8), value: steps)
    }

    /// The fog's sideways breath: the site's ±2.2% of its width.
    private func drift(_ box: SceneBox) -> CGFloat {
        guard moving else { return 0 }
        return (drifting ? 1 : -1) * 0.022 * box.fog.width
    }

    /// 0 below `from`, 1 above `to`, smooth between.
    static func ramp(_ x: Double, from a: Double, to b: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// The crossfade's quarters.
    static func step(_ x: Double) -> Double {
        x >= 1 ? 1 : (x * 4).rounded(.down) / 4
    }

    /// Seconds for the shader's shimmer, kept small so a float holds them exactly: the shimmer's period divides it.
    static func clock(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2 * .pi / 0.8 * 100)
    }
}
