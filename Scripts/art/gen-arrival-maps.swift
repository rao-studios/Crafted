#!/usr/bin/env swift
// WHAT: Bake each scene's arrival map: a small picture whose red channel says when the wash reaches each point of
//       the painting (0 first, 1 last) and whose green channel is a slow wander noise the shader shimmers the edge by.
// IN:   Design/washes/<scene>.json: the picture's size, a seed, and its regions in the order they are laid (a later
//       region wins where it overlaps an earlier one, so a statue is listed after the building it stands on). Each
//       region has a shape in fractions of the far layer (origin top-left: rect [x0 y0 x1 y1], ellipse [cx cy rx ry]
//       or polygon [[x y] …]), a sweep (down, up, left, right, out, in; out and in from `origin`, else the
//       middle), a time band [start end], and optionally its own wander.
// OUT:  Sources/CraftedApp/Resources/washes/<scene>-arrival.png (RGB, 8 bit: R arrival, G wander, B = R).
// PIN:  The front wanders: low-frequency fractal noise moves each region's sweep by up to `wander` of its band,
//       clamped inside the band, so a region never arrives before or after its slot. Regions meet over `feather`
//       (a fraction of the height), so the front crosses a boundary softly rather than on a pixel; and `edge` moves
//       every boundary by mid-frequency noise, so a region the wash paints round (a reserved white, the basilica
//       waiting in a painted sky) has a wet, wandering edge rather than a ruled one.
// PIN:  The last band ends below 1 (0.985): Shaders/Watercolour.metal stretches progress by its wet edge so that
//       progress 1 leaves no pixel unpainted.
//
//   swift Scripts/art/gen-arrival-maps.swift [scene …]      (no scene: every Design/washes/*.json)
//
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let designs = root.appendingPathComponent("Design/washes")
let outDir = root.appendingPathComponent("Sources/CraftedApp/Resources/washes")

struct Design: Decodable {
    struct Wander: Decodable { var scale: Double; var octaves: Int; var amount: Double }
    struct Edge: Decodable { var scale: Double; var amount: Double }
    struct Shape: Decodable { var rect: [Double]?; var ellipse: [Double]?; var polygon: [[Double]]? }
    struct Region: Decodable {
        var name: String
        var shape: Shape
        var sweep: String
        var origin: [Double]?
        var band: [Double]
        var wander: Double?
    }
    var scene: String
    var size: [Int]
    var seed: UInt32
    var rest: Double?
    var feather: Double
    var wander: Wander
    /// The regions' own edges wander too, as wet edges do: each shape's boundary moves by up to `amount` of the
    /// height, by noise `scale` times across the width.
    var edge: Edge?
    var regions: [Region]
}

// MARK: Noise

/// A lattice hash in 0…1, from integer coordinates and a seed.
func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Double {
    var h = UInt32(truncatingIfNeeded: x) &* 0x8da6b343 ^ UInt32(truncatingIfNeeded: y) &* 0xd8163841 ^ seed &* 0xcb1ab31f
    h ^= h >> 13; h = h &* 0x5bd1e995; h ^= h >> 15
    return Double(h & 0xffffff) / Double(0xffffff)
}

/// Smooth value noise in 0…1.
func valueNoise(_ x: Double, _ y: Double, _ seed: UInt32) -> Double {
    let xi = Int(floor(x)), yi = Int(floor(y))
    let fx = x - floor(x), fy = y - floor(y)
    let u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy)
    let a = hash(xi, yi, seed), b = hash(xi + 1, yi, seed), c = hash(xi, yi + 1, seed), d = hash(xi + 1, yi + 1, seed)
    return (a + (b - a) * u) + ((c + (d - c) * u) - (a + (b - a) * u)) * v
}

/// Fractal noise: `octaves` of value noise, each twice the frequency and half the weight of the last.
func fbm(_ x: Double, _ y: Double, octaves: Int, seed: UInt32) -> Double {
    var sum = 0.0, weight = 0.5, total = 0.0, f = 1.0
    for o in 0..<octaves {
        sum += weight * valueNoise(x * f, y * f, seed &+ UInt32(o) &* 131)
        total += weight; weight *= 0.5; f *= 2
    }
    return sum / total
}

/// A field normalised to 0…1 over the picture, so every scene's wander has the same reach.
func normalised(_ field: [Double]) -> [Double] {
    let lo = field.min() ?? 0, hi = field.max() ?? 1
    return field.map { hi > lo ? ($0 - lo) / (hi - lo) : 0.5 }
}

// MARK: Regions

func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}

/// Inside a region: a signed distance in pixels (positive inside), and its bounding box in fractions.
struct Placed {
    let region: Design.Region
    let box: (x0: Double, y0: Double, x1: Double, y1: Double)
    let w: Double, h: Double

    init(_ region: Design.Region, w: Int, h: Int) {
        self.region = region; self.w = Double(w); self.h = Double(h)
        if let r = region.shape.rect {
            box = (r[0], r[1], r[2], r[3])
        } else if let e = region.shape.ellipse {
            box = (e[0] - e[2], e[1] - e[3], e[0] + e[2], e[1] + e[3])
        } else if let p = region.shape.polygon {
            box = (p.map { $0[0] }.min()!, p.map { $0[1] }.min()!, p.map { $0[0] }.max()!, p.map { $0[1] }.max()!)
        } else {
            fatalError("region \(region.name) has no shape")
        }
    }

    func distance(_ x: Double, _ y: Double) -> Double {
        if region.shape.rect != nil {
            return min((x - box.x0) * w, (box.x1 - x) * w, (y - box.y0) * h, (box.y1 - y) * h)
        }
        if let e = region.shape.ellipse {
            let k = hypot((x - e[0]) / e[2], (y - e[1]) / e[3])
            return (1 - k) * min(e[2] * w, e[3] * h)
        }
        let p = region.shape.polygon!.map { ($0[0] * w, $0[1] * h) }
        let (px, py) = (x * w, y * h)
        var inside = false, nearest = Double.infinity
        for i in 0..<p.count {
            let a = p[i], b = p[(i + 1) % p.count]
            if (a.1 > py) != (b.1 > py), px < (b.0 - a.0) * (py - a.1) / (b.1 - a.1) + a.0 { inside.toggle() }
            let (dx, dy) = (b.0 - a.0, b.1 - a.1)
            let t = min(max(((px - a.0) * dx + (py - a.1) * dy) / max(dx * dx + dy * dy, 1e-9), 0), 1)
            nearest = min(nearest, hypot(px - (a.0 + t * dx), py - (a.1 + t * dy)))
        }
        return inside ? nearest : -nearest
    }

    /// How far through its sweep the region is at a point, 0…1.
    func sweep(_ x: Double, _ y: Double) -> Double {
        let across = (x - box.x0) / max(box.x1 - box.x0, 1e-9)
        let down = (y - box.y0) / max(box.y1 - box.y0, 1e-9)
        switch region.sweep {
        case "down": return down
        case "up": return 1 - down
        case "right": return across
        case "left": return 1 - across
        case "out", "in":
            let o = region.origin ?? [(box.x0 + box.x1) / 2, (box.y0 + box.y1) / 2]
            let corners = [(box.x0, box.y0), (box.x1, box.y0), (box.x0, box.y1), (box.x1, box.y1)]
            let reach = corners.map { hypot(($0.0 - o[0]) * w, ($0.1 - o[1]) * h) }.max()!
            let r = min(hypot((x - o[0]) * w, (y - o[1]) * h) / max(reach, 1e-9), 1)
            return region.sweep == "out" ? r : 1 - r
        default: fatalError("region \(region.name): unknown sweep \(region.sweep)")
        }
    }
}

// MARK: Bake

func bake(_ design: Design) -> CGImage {
    let (w, h) = (design.size[0], design.size[1])
    let aspect = Double(h) / Double(w)
    let edge = design.edge ?? .init(scale: 9, amount: 0)
    var wander = [Double](), shimmer = [Double](), ragged = [Double]()
    wander.reserveCapacity(w * h); shimmer.reserveCapacity(w * h); ragged.reserveCapacity(w * h)
    for j in 0..<h {
        for i in 0..<w {
            let (x, y) = ((Double(i) + 0.5) / Double(w), (Double(j) + 0.5) / Double(h))
            wander.append(fbm(x * design.wander.scale, y * design.wander.scale * aspect, octaves: design.wander.octaves, seed: design.seed))
            shimmer.append(fbm(x * 1.6, y * 1.6 * aspect, octaves: 2, seed: design.seed &+ 101))
            ragged.append(fbm(x * edge.scale, y * edge.scale * aspect, octaves: 3, seed: design.seed &+ 211))
        }
    }
    wander = normalised(wander); shimmer = normalised(shimmer); ragged = normalised(ragged)

    let placed = design.regions.map { Placed($0, w: w, h: h) }
    let feather = design.feather * Double(h)
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    for j in 0..<h {
        for i in 0..<w {
            let (x, y) = ((Double(i) + 0.5) / Double(w), (Double(j) + 0.5) / Double(h))
            let n = (wander[j * w + i] - 0.5) * 2
            let shift = (ragged[j * w + i] - 0.5) * 2 * edge.amount * Double(h)
            var value = design.rest ?? 0.5
            for p in placed {
                let mask = smoothstep(-feather, feather, p.distance(x, y) + shift)
                guard mask > 0 else { continue }
                let amount = p.region.wander ?? design.wander.amount
                let t = min(max(p.sweep(x, y) + amount * n, 0), 1)
                let arrives = p.region.band[0] + (p.region.band[1] - p.region.band[0]) * t
                value += (arrives - value) * mask
            }
            let k = (j * w + i) * 4
            let r = UInt8(min(max(value, 0), 1) * 255 + 0.5)
            pixels[k] = r
            pixels[k + 1] = UInt8(shimmer[j * w + i] * 255 + 0.5)
            pixels[k + 2] = r
            pixels[k + 3] = 255
        }
    }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider,
                   decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

func write(_ image: CGImage, to url: URL) {
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("could not write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
    print("wrote \(url.path.replacingOccurrences(of: root.path + "/", with: ""))")
}

let asked = Array(CommandLine.arguments.dropFirst())
let scenes = asked.isEmpty
    ? (try! FileManager.default.contentsOfDirectory(atPath: designs.path)).filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
    : asked
for scene in scenes {
    let data = try! Data(contentsOf: designs.appendingPathComponent("\(scene).json"))
    let design = try! JSONDecoder().decode(Design.self, from: data)
    write(bake(design), to: outDir.appendingPathComponent("\(design.scene)-arrival.png"))
}
