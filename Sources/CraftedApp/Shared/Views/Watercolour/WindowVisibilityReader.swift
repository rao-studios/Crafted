//  WHAT: Says whether the window a view sits in can be seen, so a painting stops redrawing its wash while the
//        window is hidden, minimised or covered.
//  IN:   A binding the reader sets.
//  OUT:  An invisible, unclickable view; true while any part of its window is visible (and before it has a window).
//  PIN:  NSWindow.occlusionState, observed per window. SwiftUI keeps a TimelineView running for an occluded window.

import AppKit
import SwiftUI

struct WindowVisibilityReader: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> Probe {
        let probe = Probe()
        probe.onChange = { visible in if isVisible != visible { isVisible = visible } }
        return probe
    }

    func updateNSView(_ probe: Probe, context: Context) {
        probe.onChange = { visible in if isVisible != visible { isVisible = visible } }
    }

    static func dismantleNSView(_ probe: Probe, coordinator: ()) {
        probe.stopObserving()
    }

    final class Probe: NSView {
        var onChange: ((Bool) -> Void)?
        private var observer: NSObjectProtocol?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
            report()
        }

        func stopObserving() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }

        private func report() {
            let visible = window?.occlusionState.contains(.visible) ?? true
            // Never during SwiftUI's update of the view that holds the binding.
            DispatchQueue.main.async { [weak self] in self?.onChange?(visible) }
        }
    }
}
