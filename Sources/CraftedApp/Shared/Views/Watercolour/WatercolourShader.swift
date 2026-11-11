//  WHAT: The wash shader (Shaders/Watercolour.metal, compiled to Resources/Watercolour.metallib), loaded by hand.
//  OUT:  A Shader for `colorEffect`, or nil when the library is missing or turned off; ScenePainting then crossfades.
//  PIN:  ShaderLibrary(url:) from the bundle WatercolourResources finds, never `ShaderLibrary.default` or
//        `Bundle.module`: neither finds a SwiftPM resource bundle inside an assembled .app.
//  PIN:  CRAFTED_WATERCOLOUR=crossfade turns the shader off, to see the fallback (or to spare a busy GPU).

import SwiftUI

enum WatercolourShader {
    static let library: ShaderLibrary? = {
        if ProcessInfo.processInfo.environment["CRAFTED_WATERCOLOUR"] == "crossfade" { return nil }
        return WatercolourResources.url("Watercolour.metallib").map { ShaderLibrary(url: $0) }
    }()

    static var isAvailable: Bool { library != nil }

    /// The wash over a layer `size` points large (the box the arrival map covers), at `progress`, its edge
    /// shimmering by `time`.
    static func wash(size: CGSize, progress: Double, time: Double, arrival: CGImage) -> Shader? {
        guard let library else { return nil }
        return Shader(
            function: ShaderFunction(library: library, name: "wash"),
            arguments: [
                .float2(size),
                .float(progress),
                .float(time),
                .image(Image(decorative: arrival, scale: 1)),
            ]
        )
    }
}
