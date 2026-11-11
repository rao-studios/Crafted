//  WHAT: Ctrl-C as a cancel: the first SIGINT runs the handler (the run stops and stays resumable), a second ends
//        the process at once.

import Foundation

enum Interrupt {
    nonisolated(unsafe) private static var source: DispatchSourceSignal?
    nonisolated(unsafe) private static var count = 0

    static func onInterrupt(_ handler: @escaping @Sendable () -> Void) {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            count += 1
            if count > 1 { exit(130) }
            FileHandle.standardError.write(Data("\n[check] interrupted: cancelling the run (Ctrl-C again to quit)\n".utf8))
            handler()
        }
        source.resume()
        self.source = source
    }
}
