//  WHAT: Which build is running: the version and build from Info.plist, and what make-app.sh stamps into the bundle's
//        copy (CraftedBuildCommit, CraftedBuildDate, CraftedDependencyCommits), for Settings › About.
//  PIN:  A development build (the bare binary dev.sh runs) has no stamps and says so.

import CryptoKit
import Foundation

struct BuildInfo: Equatable {
    var version: String?
    var build: String?
    var commit: String?
    var builtAt: Date?
    /// "frigate=…, granite=…".
    var dependencies: [(name: String, commit: String)]

    static let current: BuildInfo = {
        let info = Bundle.main.infoDictionary ?? [:]
        let stamped = (info["CraftedDependencyCommits"] as? String) ?? ""
        let dependencies = stamped.split(separator: " ").compactMap { pair -> (String, String)? in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        }
        return BuildInfo(version: info["CFBundleShortVersionString"] as? String, build: info["CFBundleVersion"] as? String,
                         commit: info["CraftedBuildCommit"] as? String,
                         builtAt: (info["CraftedBuildDate"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) },
                         dependencies: dependencies)
    }()

    var isDevelopment: Bool { commit == nil }

    var title: String { "Crafted \(version ?? "0.0.0") (\(build ?? "0"))" }

    /// The running executable's MD5, taken once off the main thread.
    static let executableMD5: Task<String?, Never> = Task.detached(priority: .utility) {
        guard let url = Bundle.main.executableURL, let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func abbreviated(_ hash: String) -> String { String(hash.prefix(7)) }

    static func == (lhs: BuildInfo, rhs: BuildInfo) -> Bool {
        lhs.version == rhs.version && lhs.build == rhs.build && lhs.commit == rhs.commit && lhs.builtAt == rhs.builtAt
    }
}
