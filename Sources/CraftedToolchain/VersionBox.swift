//  WHAT: The toolchain's version (or why there is none), looked up once per SwiftToolchain and kept.

import Foundation

/// The toolchain's version, looked up once per SwiftToolchain.
final class VersionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: (version: String?, reason: String?)?

    var value: (version: String?, reason: String?)? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
