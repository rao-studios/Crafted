import SwiftUI
import AppKit

enum CraftLayout {
    /// A window's first size and the smallest it can be made.
    struct WindowSize {
        let ideal: CGSize
        let floor: CGSize
    }

    static let screenMargin = CGSize(width: 80, height: 60)

    static let settings = WindowSize(ideal: CGSize(width: 900, height: 620), floor: CGSize(width: 760, height: 520))
    /// The onboarding: a band of painting over a step's cards and actions, fixed.
    static let onboarding = WindowSize(ideal: CGSize(width: 720, height: 640), floor: CGSize(width: 720, height: 640))
    /// The Workshop: the drop leaf over two rows of tiles; a run's painting beside its stage list.
    static let workshop = WindowSize(ideal: CGSize(width: 1120, height: 780), floor: CGSize(width: 820, height: 600))

    /// Home's grid of generations.
    enum Library {
        /// A tile's narrowest: the grid adds a column each time this much more fits.
        static let tileMin: CGFloat = 220
        static let tileIcon: CGFloat = 44
        /// A tile's height, so a row of tiles lines up whatever their names say.
        static let tileHeight: CGFloat = 150
        /// The drop leaf's height above the grid.
        static let leafHeight: CGFloat = 300
    }

    /// The Generation page: the painting, the stage column beside it.
    enum Run {
        static let stageColumn: CGFloat = 320
        static let paintingMin: CGFloat = 280
        /// The listing panel over a live run: the form at a reading width.
        static let panelWidth: CGFloat = 560
    }

    /// The listing form's icon well.
    static let iconWell: CGFloat = 112
    /// A column edge's grab area: wider than the hairline it draws, so it is easy to catch.
    static let columnGrab: CGFloat = 9
    /// A Settings page's reading width.
    static let settingsMeasure: CGFloat = 620

    /// Caps the ideal size to the visible screen.
    static func fittedDefaultSize(_ ideal: CGSize) -> CGSize {
        guard let visible = NSScreen.main?.visibleFrame.size else { return ideal }
        return CGSize(
            width: min(ideal.width, visible.width - screenMargin.width),
            height: min(ideal.height, visible.height - screenMargin.height))
    }
}
