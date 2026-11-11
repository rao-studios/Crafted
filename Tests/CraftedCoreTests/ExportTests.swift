//  WHAT: What ships: the export filter's table, and a zip that unzips (with ditto, as Finder would) to exactly the
//        filtered tree: no .build, .swiftpm, .git or .DS_Store; .gitignore kept.

@testable import CraftedCore
import XCTest

final class ExportTests: XCTestCase {
    func testFilterTable() {
        let ships = ["Package.swift", ".gitignore", ".github/workflows/craft-listing.yml", ".spi.yml", "Sources/A/A.swift",
                     "Assets/icon.png", "Tests/ATests/Fixtures/in.json"]
        let dropped = [".build", ".build/debug/x", ".swiftpm/xcode", ".git/HEAD", ".DS_Store", "Sources/.DS_Store", "._icon.png",
                       "Sources/A/._A.swift", "x.xcodeproj/xcuserdata/me.xcuserstate", "DerivedData/x", ".crafted/run", ".env",
                       "Sources/.hidden"]
        for path in ships { XCTAssertTrue(ExportFilter.includes(path), path) }
        for path in dropped { XCTAssertFalse(ExportFilter.includes(path), path) }
    }

    func testZipRoundTrip() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let package = root.appendingPathComponent("InvoiceTotalsAgent", isDirectory: true)
        let files = [
            "Package.swift": "// manifest", ".gitignore": ".build/\n", "README.md": "# Invoice Totals",
            "Sources/InvoiceTotalsAgent/A.swift": "let a = 1", "Assets/listing.json": "{}",
            ".build/debug/junk": "x", ".swiftpm/config": "x", ".git/HEAD": "ref", ".DS_Store": "x", "Sources/.DS_Store": "x",
        ]
        for (path, text) in files {
            let url = package.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        let zip = root.appendingPathComponent("out/InvoiceTotalsAgent.zip")
        try fm.createDirectory(at: zip.deletingLastPathComponent(), withIntermediateDirectories: true)
        let shipped = try PackageExport.zip(package: package, named: "InvoiceTotalsAgent", to: zip)
        let expected = [".gitignore", "Assets/listing.json", "Package.swift", "README.md", "Sources/InvoiceTotalsAgent/A.swift"]
        XCTAssertEqual(shipped, expected)
        XCTAssertFalse(fm.fileExists(atPath: zip.path + ".partial"))

        let unzipped = root.appendingPathComponent("unzipped", isDirectory: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, unzipped.path]
        try ditto.run()
        ditto.waitUntilExit()
        XCTAssertEqual(ditto.terminationStatus, 0)
        let top = try fm.contentsOfDirectory(atPath: unzipped.path).filter { $0 != "__MACOSX" }
        XCTAssertEqual(top, ["InvoiceTotalsAgent"])
        let tree = unzipped.appendingPathComponent("InvoiceTotalsAgent")
        let found = (fm.enumerator(atPath: tree.path)?.allObjects as? [String] ?? [])
            .filter { path in
                var isDirectory: ObjCBool = false
                fm.fileExists(atPath: tree.appendingPathComponent(path).path, isDirectory: &isDirectory)
                return !isDirectory.boolValue
            }.sorted()
        XCTAssertEqual(found, expected)
        for path in expected {
            XCTAssertEqual(try String(contentsOf: tree.appendingPathComponent(path), encoding: .utf8), files[path], path)
        }
    }

    func testZipOfNothingSaysSo() {
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
        XCTAssertThrowsError(try PackageExport.zip(package: missing, named: "X", to: missing.appendingPathExtension("zip")))
    }
}
