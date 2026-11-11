//  WHAT: Runs one tool (swift, an agent's runner) to its end: stdout and stderr read whole, each on a thread of its
//        own, under a deadline, and ended with its whole process group when the deadline passes or the task is
//        cancelled.
//  IN:   An absolute executable and its arguments, a folder to run in.
//  OUT:  SwiftToolchain's version, build, test and describe.
//  PIN:  BOTH PIPES, AT ONCE. A build that fills stderr while stdout is being waited on never finishes; each pipe has
//        its reader from the moment the process starts.
//  PIN:  THE GROUP, NOT THE PID. `swift build` runs swift-frontend children; the process starts in a group of its
//        own so a cancel ends all of them (SIGTERM, then SIGKILL after the grace), as Craft's ProcessRunner does.
//  PIN:  THE CHILD STARTS WITH NO SIGNAL BLOCKED: this runs on a dispatch worker, whose mask blocks SIGTERM, and a
//        spawned child inherits it.

import Darwin
import Foundation

enum ToolProcess {
    struct Output: Sendable {
        var status: Int32
        var stdout: String
        var stderr: String
        var timedOut: Bool
        var seconds: Double

        var combined: String { stderr.isEmpty ? stdout : stdout + "\n" + stderr }
    }

    struct SpawnFailure: Error, CustomStringConvertible {
        let path: String
        let code: Int32
        var description: String { "could not start \(path): \(String(cString: strerror(code)))" }
    }

    /// Seconds between SIGTERM and SIGKILL.
    static let grace: TimeInterval = 3

    /// Runs `arguments` (the first an absolute path) in `directory`. Throws CancellationError when the task was
    /// cancelled; a passed deadline answers `timedOut`.
    static func run(_ arguments: [String], in directory: URL, timeout: TimeInterval,
                    environment: [String: String] = cleanEnvironment()) async throws -> Output {
        let stop = StopFlag()
        let output: Output = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        continuation.resume(returning: try runBlocking(arguments, in: directory, timeout: timeout,
                                                                       environment: environment, stop: stop))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            stop.set()
        }
        if stop.isSet { throw CancellationError() }
        return output
    }

    /// The environment a tool runs in: this process's, without a test runner's loader paths, without colour.
    static func cleanEnvironment(adding extra: [String: String] = [:]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("DYLD_") && !$0.key.hasPrefix("XCTest") }
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        for (key, value) in extra { environment[key] = value }
        return environment
    }

    private static func runBlocking(_ arguments: [String], in directory: URL, timeout: TimeInterval,
                                    environment: [String: String], stop: StopFlag) throws -> Output {
        let started = Date()
        var outPipe: [Int32] = [0, 0]
        var errPipe: [Int32] = [0, 0]
        guard pipe(&outPipe) == 0 else { throw SpawnFailure(path: arguments.first ?? "", code: errno) }
        guard pipe(&errPipe) == 0 else {
            close(outPipe[0]); close(outPipe[1])
            throw SpawnFailure(path: arguments.first ?? "", code: errno)
        }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, outPipe[1], 1)
        posix_spawn_file_actions_adddup2(&actions, errPipe[1], 2)
        posix_spawn_file_actions_addchdir_np(&actions, directory.path)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        var unblocked = sigset_t()
        sigemptyset(&unblocked)
        posix_spawnattr_setsigmask(&attributes, &unblocked)
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for signal in [SIGTERM, SIGINT, SIGHUP, SIGQUIT, SIGPIPE] { sigaddset(&defaults, signal) }
        posix_spawnattr_setsigdefault(&attributes, &defaults)
        posix_spawnattr_setpgroup(&attributes, 0)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
                                                     | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))

        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }

        var pid: pid_t = 0
        let status = posix_spawn(&pid, arguments[0], &actions, &attributes, argv, envp)
        close(outPipe[1]); close(errPipe[1])
        guard status == 0 else {
            close(outPipe[0]); close(errPipe[0])
            throw SpawnFailure(path: arguments[0], code: status)
        }

        let out = Collected()
        let err = Collected()
        let readers = DispatchGroup()
        for (fd, sink) in [(outPipe[0], out), (errPipe[0], err)] {
            readers.enter()
            let thread = Thread {
                var buffer = [UInt8](repeating: 0, count: 65_536)
                while true {
                    let count = read(fd, &buffer, buffer.count)
                    if count < 0, errno == EINTR { continue }
                    if count <= 0 { break }
                    sink.append(buffer[0..<count])
                }
                close(fd)
                readers.leave()
            }
            thread.name = "crafted.toolchain.read"
            thread.start()
        }

        let deadline = started.addingTimeInterval(timeout)
        var timedOut = false
        var exitStatus: Int32 = -1
        var signalledAt: Date?
        while true {
            var raw: Int32 = 0
            let waited = waitpid(pid, &raw, WNOHANG)
            if waited == pid {
                exitStatus = (raw & 0x7f) == 0 ? (raw >> 8) & 0xff : 128 + (raw & 0x7f)
                break
            }
            if waited < 0, errno != EINTR { break }
            if let signalledAt {
                if Date().timeIntervalSince(signalledAt) > grace { kill(-pid, SIGKILL) }
            } else if stop.isSet || Date() > deadline {
                timedOut = !stop.isSet
                kill(-pid, SIGTERM)
                signalledAt = Date()
            }
            usleep(20_000)
        }
        // A grandchild still holding a pipe is not waited for past a short grace.
        _ = readers.wait(timeout: .now() + .seconds(5))
        return Output(status: exitStatus, stdout: out.text, stderr: err.text, timedOut: timedOut,
                      seconds: Date().timeIntervalSince(started))
    }

    /// Bytes from one pipe, appended from its reader thread.
    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func append(_ bytes: ArraySlice<UInt8>) { lock.withLock { data.append(contentsOf: bytes) } }
        var text: String { lock.withLock { String(decoding: data, as: UTF8.self) } }
    }

    /// Set once by the cancelling task, read by the wait loop on its own thread.
    final class StopFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.withLock { value } }
        func set() { lock.withLock { value = true } }
    }
}
