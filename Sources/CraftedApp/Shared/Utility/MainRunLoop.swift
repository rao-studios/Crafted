//  WHAT: Work for the main thread, run from the main run loop rather than from a block on the main
//        dispatch queue.
//  IN:   The launch after the onboarding gate (CraftedAppRoot.afterOnboarding): anything that opens a window
//        from async code.
//  PIN:  FROM CRAFT, WHERE OPENING A PROJECT WAITED ON THE MAIN QUEUE (git read with Process.waitUntilExit, which
//        learns the child has exited through the main queue). A main-actor task is a block on that queue, so a window
//        opened from one waited for a block that could not run until it returned: the launch hung with no window
//        (2026-10-26). From the run loop the queue is free, as it is in an AppKit callback.

import Foundation

@MainActor
enum MainRunLoop {
    static func perform(_ work: @escaping @MainActor () -> Void) {
        RunLoop.main.perform(inModes: [.default, .eventTracking, .modalPanel]) {
            MainActor.assumeIsolated { work() }
        }
    }
}
