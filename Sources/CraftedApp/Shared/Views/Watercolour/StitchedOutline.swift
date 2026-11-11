//  WHAT: The icon's ring of French knots as an outline: evenly spaced dots along a rounded rectangle, for the drop
//        zone's drag-over state.
//  IN:   The corner radius, the spacing between knots along the edge, a knot's radius, its thread.
//  OUT:  A view that fills its frame with the ring, inset by a knot so none is cut.
//  PIN:  Spaced by length along the edge, not by angle, and closing evenly (the count rounds, the gap stretches), as
//        Scripts/art/gen-app-icon.swift spaces the icon's knots round its squircle. A corner as large as the side
//        allows makes the ring the icon's: a square frame with a large radius reads as its squircle.

import SwiftUI

struct StitchedOutline: View {
    private let cornerRadius: CGFloat
    private let spacing: CGFloat
    private let dotRadius: CGFloat
    private let color: Color

    init(cornerRadius: CGFloat = 18, spacing: CGFloat = 9, dotRadius: CGFloat = 1.6, color: Color = WatercolourPalette.brass) {
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.dotRadius = dotRadius
        self.color = color
    }

    var body: some View {
        Canvas { context, size in
            let knots = Self.knots(in: CGRect(origin: .zero, size: size).insetBy(dx: dotRadius, dy: dotRadius),
                                   cornerRadius: cornerRadius, spacing: spacing)
            var path = Path()
            for knot in knots {
                path.addEllipse(in: CGRect(x: knot.x - dotRadius, y: knot.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
            context.fill(path, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Points round `rect`'s rounded outline, about `spacing` apart by length, the first at the top edge's middle.
    static func knots(in rect: CGRect, cornerRadius: CGFloat, spacing: CGFloat) -> [CGPoint] {
        guard rect.width > 0, rect.height > 0, spacing > 0 else { return [] }
        let r = min(max(cornerRadius, 0), rect.width / 2, rect.height / 2)
        let straightX = rect.width - 2 * r, straightY = rect.height - 2 * r
        let arc = CGFloat.pi / 2 * r
        // Clockwise from the top's middle: half the top, a corner, the right, a corner, the bottom, a corner,
        // the left, a corner, the other half of the top.
        let segments: [CGFloat] = [straightX / 2, arc, straightY, arc, straightX, arc, straightY, arc, straightX / 2]
        let total = segments.reduce(0, +)
        let count = max(Int((total / spacing).rounded()), 4)
        let corners = [
            CGPoint(x: rect.maxX - r, y: rect.minY + r), CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            CGPoint(x: rect.minX + r, y: rect.maxY - r), CGPoint(x: rect.minX + r, y: rect.minY + r),
        ]
        return (0..<count).map { k in
            var d = CGFloat(k) / CGFloat(count) * total
            for (index, length) in segments.enumerated() {
                if d > length, index < segments.count - 1 {
                    d -= length
                    continue
                }
                let f = length > 0 ? d / length : 0
                switch index {
                case 0: return CGPoint(x: rect.midX + d, y: rect.minY)
                case 2: return CGPoint(x: rect.maxX, y: rect.minY + r + d)
                case 4: return CGPoint(x: rect.maxX - r - d, y: rect.maxY)
                case 6: return CGPoint(x: rect.minX, y: rect.maxY - r - d)
                case 8: return CGPoint(x: rect.minX + r + d, y: rect.minY)
                default:
                    // Corners 1, 3, 5, 7: a quarter turn each, starting at -90°, 0°, 90°, 180°.
                    let corner = corners[(index - 1) / 2]
                    let angle = (-CGFloat.pi / 2) + CGFloat((index - 1) / 2) * (CGFloat.pi / 2) + f * (CGFloat.pi / 2)
                    return CGPoint(x: corner.x + r * cos(angle), y: corner.y + r * sin(angle))
                }
            }
            return CGPoint(x: rect.midX, y: rect.minY)
        }
    }
}
