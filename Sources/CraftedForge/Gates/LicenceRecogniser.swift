//  WHAT: Which licence a LICENSE file is, read off its opening as the store reads it: MIT, Apache-2.0, MPL-2.0,
//        GPL-3.0, BSD-3-Clause, BSD-2-Clause or ISC, else none.
//  IN:   craft.rao.nyc app/(store)/_lib/formats/swift-package/sources.ts `licenseIn`, and index.ts's LICENSE_FILES
//        (the first of LICENSE, LICENSE.md, LICENSE.txt, LICENCE, LICENCE.md that exists is the one read).
//  OUT:  StoreValidator (the store's "recognised LICENSE"), ShipGate (the package's licence, for the copyleft scan).
//  PIN:  THE STORE'S TESTS, NOT A BETTER GUESS. The first 600 characters decide, except MIT's grant sentence, which
//        may sit in the first 1500; the order of the checks is the store's.

import CraftedCore
import Foundation

public enum LicenceRecogniser {
    /// The store's candidate LICENSE files, in the order it looks.
    public static let files = ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "LICENCE.md"]

    /// The licence `text` says it is, plainly, or nil.
    public static func licence(in text: String) -> ListingLicence? {
        let head = String(text.prefix(600))
        func has(_ pattern: String, _ inText: String) -> Bool {
            inText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        if has(#"\bMIT License\b"#, head) || has("Permission is hereby granted, free of charge", String(text.prefix(1500))) { return .mit }
        if has("Apache License", head), has(#"Version 2\.0"#, head) { return .apache2 }
        if has(#"Mozilla Public License,? (?:Version|v\.?) ?2\.0"#, head) { return .mpl2 }
        if has("GNU GENERAL PUBLIC LICENSE", head), has("Version 3", head) { return .gpl3 }
        if has("BSD 3-Clause", head) { return .bsd3 }
        if has("BSD 2-Clause", head) { return .bsd2 }
        if has(#"^\s*ISC License"#, head) { return .isc }
        return nil
    }

    /// The package's LICENSE file as the store picks it: its relative path and text, or nil when there is none.
    public static func licenceFile(in package: URL) -> (path: String, text: String)? {
        for name in files {
            let url = package.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            return (name, (try? String(contentsOf: url, encoding: .utf8)) ?? "")
        }
        return nil
    }

    /// The licence of the package at `package`, as the store would recognise it.
    public static func licence(ofPackage package: URL) -> ListingLicence? {
        licenceFile(in: package).flatMap { licence(in: $0.text) }
    }
}
