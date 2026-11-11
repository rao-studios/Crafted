//  WHAT: Package.resolved: which Granite commit the package was built against, for every version SwiftPM has
//        written: 1 (`object.pins`, keyed by `package` and `repositoryURL`), 2 and 3 (`pins`, keyed by `identity` and
//        `location`). Only a full 40-hex revision counts.
//  IN:   craft.rao.nyc app/(store)/_lib/formats/swift-package/resolved.ts, ported.
//  OUT:  StoreInspection.

import Foundation

public enum ResolvedReader {
    public static func graniteRevision(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let pins = (root["pins"] as? [Any]) ?? ((root["object"] as? [String: Any])?["pins"] as? [Any]) ?? []
        for case let pin as [String: Any] in pins {
            let location = (pin["location"] as? String) ?? (pin["repositoryURL"] as? String)
            let identity = (pin["identity"] as? String)?.lowercased()
                ?? location.map(SwiftManifestReader.packageIdentity)
                ?? (pin["package"] as? String)?.lowercased()
            guard identity == "granite" else { continue }
            if let revision = (pin["state"] as? [String: Any])?["revision"] as? String, StoreRegex.whole("[0-9a-f]{40}", revision) {
                return revision
            }
        }
        return nil
    }
}
