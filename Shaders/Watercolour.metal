//  WHAT: The wash: a SwiftUI colour effect that paints a watercolour layer in as `progress` passes each point's
//        arrival time. Ahead of the front the paper shows; at the front the edge is wet and frayed, the pigment
//        pools darker where it is drying, and the paper's tooth breaks it up; behind it the painting settles to
//        exactly itself.
//  IN:   position, color (SwiftUI's, premultiplied); size (the layer's size in points, the box the arrival map
//        covers); progress 0…1; time in seconds (the edge shimmers by it); arrival, the scene's baked map
//        (Scripts/art/gen-arrival-maps.swift: R when the wash arrives, G a slow wander noise).
//  OUT:  The layer's colour, premultiplied, with the wash's coverage.
//  PIN:  A PORT OF THE SITE'S RECIPE (craft.rao.nyc, app/(home)/_components/hero-painting.tsx, the `wc` filter):
//        the edge displaced by low-frequency fractal noise; the rim darkened as 1.55·blur(A,1) − 0.78·blur(A,7)
//        darkens it; the tooth as clamp(1.28 − 0.75·noise). Here the blurs are two ramps of the time since the
//        wash arrived, a narrow one (`wet`) and a wide one (`pool`), and the darkening is the pigment multiplied
//        into itself, as a second layer of the same paint is.
//  PIN:  PROGRESS 1 PAINTS EVERYTHING. The map's last band ends at 0.985 and the fray and shimmer move it by at
//        most ~0.02, so progress is stretched by `reach` (> wet + the grain's span + that) and the last point is
//        clean, rim and tooth gone, at 1. The view also drops the effect at 1.
//  PIN:  Compiled by Scripts/build/build-shaders.sh into Sources/CraftedApp/Resources/Watercolour.metallib, with this
//        file's SHA-256 beside it. Change this file, run the script, commit both.

#include <metal_stdlib>
using namespace metal;

namespace watercolour {

/// A hash in 0…1 for a lattice point.
inline float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// Smooth value noise in 0…1.
inline float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// Fractal noise, three octaves, in 0…1: the site's feTurbulence fractalNoise, numOctaves 3.
inline float fbm(float2 p) {
    float sum = 0.0;
    float weight = 0.5;
    for (int octave = 0; octave < 3; octave++) {
        sum += weight * noise(p);
        p = p * 2.03 + float2(17.1, 9.7);
        weight *= 0.5;
    }
    return sum / 0.875;
}

/// The paper's tooth, two octaves of fine noise: the site's feTurbulence at 0.6, numOctaves 2.
inline float grain(float2 p) {
    return (noise(p) * 0.667 + noise(p * 2.1 + float2(3.7, 1.3)) * 0.333);
}

}  // namespace watercolour

[[ stitchable ]] half4 wash(float2 position, half4 color, float2 size, float progress, float time, texture2d<half> arrival) {
    // The wet edge's width, the band behind it where pigment pools, the band where the tooth shows, and the
    // stretch that leaves nothing unpainted at 1: all in units of progress.
    const float wet = 0.035;
    const float pool = 0.08;
    const float tooth = 0.11;
    const float reach = 0.15;

    constexpr sampler bilinear(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = clamp(position / max(size, float2(1.0)), float2(0.0), float2(1.0));
    half4 map = arrival.sample(bilinear, uv);
    float when = float(map.r);
    float drift = float(map.g);

    // The front frays as wet paint does (the site displaces by fractal noise at 0.016 of its 1600-wide frame,
    // about 0.03 a point here), and shimmers slowly where the map's wander says, never all at once.
    float fray = watercolour::fbm(position * 0.03) - 0.5;
    float shimmer = (drift - 0.5) * sin(time * 0.8 + drift * 12.566);
    when = max(when + fray * 0.03 + shimmer * 0.012, 0.004);

    // How long ago the wash reached this point, in progress.
    float since = progress * (1.0 + reach) - when;
    if (since <= 0.0) {
        return half4(0.0h);
    }

    // The edge: a narrow ramp (blur(A,1)) and a wide one (blur(A,7)); where the narrow has risen and the wide has
    // not, the pigment has pooled. Weighted as the site weights them, then kept to the rim alone.
    float soft = smoothstep(0.0, wet, since);
    float wide = smoothstep(0.0, pool, since);
    float pooled = clamp(1.55 * soft - 0.78 * wide - 0.77 * soft, 0.0, 1.0);
    float rim = clamp(pooled * 2.6, 0.0, 1.0);

    // The tooth: clamp(1.28 − 0.75·noise), only near the front, so the dried wash is the painting itself.
    float n = watercolour::grain(position * 0.62);
    float teeth = clamp(1.28 - 0.75 * n, 0.0, 1.0);
    float front = 1.0 - smoothstep(0.0, tooth, since);
    float cover = soft * mix(1.0, teeth, front);

    // Pigment pooled: the straight colour multiplied into itself at the rim (a second coat of the same paint).
    float alpha = float(color.a);
    if (alpha <= 0.0) {
        return half4(0.0h);
    }
    float3 straight = float3(color.rgb) / alpha;
    float3 pigment = mix(straight, straight * straight, 0.55 * rim);
    float a = alpha * cover;
    return half4(half3(pigment * a), half(a));
}
