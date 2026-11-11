//  WHAT: Where a painting sits in a frame of another shape: scaled to cover it (the site's object-fit: cover) and
//        cropped about the scene's focus.
//  IN:   The frame's size and the focus (fractions of the painting kept in view).
//  OUT:  The painting's size and its top-left in the frame; the fog's size (a little wider, to drift).
//  PIN:  Every layer shares the box, so far, near, fog, blooms and the arrival map stay in register: the near and
//        fog layers are 1600×900 and the far 2120×1193, the same 16:9 drawn at two resolutions.

import CoreGraphics

struct SceneBox: Equatable {
    /// The paintings' aspect, width over height.
    static let aspect: CGFloat = 16 / 9
    /// The fog is this much wider than the painting, as the site's (left −5%, width 110%), so it can drift.
    static let fogWidth: CGFloat = 1.1

    let frame: CGSize
    let fill: CGSize
    let origin: CGPoint

    init(frame: CGSize, focus: (x: CGFloat, y: CGFloat)) {
        self.frame = frame
        let width = max(frame.width, frame.height * Self.aspect)
        let height = width / Self.aspect
        fill = CGSize(width: width, height: height)
        // The focus stays as near the frame's middle as the painting's edges allow.
        let x = min(max(frame.width / 2 - focus.x * width, frame.width - width), 0)
        let y = min(max(frame.height / 2 - focus.y * height, frame.height - height), 0)
        origin = CGPoint(x: x, y: y)
    }

    var fog: CGSize { CGSize(width: fill.width * Self.fogWidth, height: fill.height * Self.fogWidth) }
}
