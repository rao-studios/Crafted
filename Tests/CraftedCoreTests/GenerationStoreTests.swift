//  WHAT: The generation store in a temporary home: create writes a record and a first listing; update stamps the
//        record; the person's save marks identity; the forge's suggestion merges under the person's edits; icons and
//        deletion.

@testable import CraftedCore
import CoreGraphics
import XCTest

final class GenerationStoreTests: XCTestCase {
    var home: URL!
    var store: GenerationStore!

    override func setUp() {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)", isDirectory: true)
        store = GenerationStore(home: CraftedHome(root: home))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    func testCreateUpdateSaveSuggest() async throws {
        let created = try await store.create(role: .designer, source: URL(fileURLWithPath: "/work/Swiss Mono"), credit: "Ada")
        XCTAssertEqual(created.status, .generating)
        XCTAssertEqual(created.sourceName, "Swiss Mono")
        let first = await store.listing(created.id)
        XCTAssertEqual(first?.name, "Swiss Mono")
        XCTAssertEqual(first?.word, "swissmono")
        XCTAssertEqual(first?.category, .graphics)
        XCTAssertEqual(first?.credit?.designer, "Ada")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.runURL(created.id).path))

        let updated = try await store.update(created.id) { $0.stage = "Looking"; $0.fraction = 0.4 }
        XCTAssertEqual(updated?.stage, "Looking")
        XCTAssertGreaterThanOrEqual(updated!.updated, created.updated)
        let missing = try await store.update("nope") { _ in }
        XCTAssertNil(missing)

        // The person renames it and writes a tagline.
        var mine = first!
        mine.name = "Mono Posters"
        mine.word = "monoposters"
        mine.tagline = "Posters in Swiss Mono."
        mine.edited = [.name, .word, .tagline]
        try await store.saveListing(mine, created.id)
        let saved = await store.record(created.id)
        XCTAssertEqual(saved?.identity?.package, "MonoPostersAgent")
        XCTAssertEqual(saved?.title, "Mono Posters")

        // The forge's suggestion fills only what the person left.
        let suggestion = AgentListing(name: "Swiss Style", word: "swissstyle", tagline: "Suggested.", category: .media,
                                      keywords: ["posters"], credit: ListingCredit(designer: "Ada", url: "https://ada.dev"))
        let merged = try await store.suggestListing(suggestion, created.id)
        XCTAssertEqual(merged.name, "Mono Posters")
        XCTAssertEqual(merged.word, "monoposters")
        XCTAssertEqual(merged.tagline, "Posters in Swiss Mono.")
        XCTAssertEqual(merged.category, .media)
        XCTAssertEqual(merged.keywords, ["posters"])
        let kept = await store.listing(created.id)
        XCTAssertEqual(kept, merged)
        let list = await store.list()
        XCTAssertEqual(list.map(\.id), [created.id])
    }

    func testIconIsNormalisedAndMarkedEdited() async throws {
        let created = try await store.create(role: .engineer, source: URL(fileURLWithPath: "/work/tax"), credit: nil)
        let picture = home.appendingPathComponent("wide.png")
        let context = CGContext(data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        try IconNormaliser.pngData(context.makeImage()!).write(to: picture)

        try await store.setIcon(from: picture, created.id)
        let icon = await store.icon(created.id)
        let source = CGImageSourceCreateWithURL(icon! as CFURL, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 1024)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1024)
        let listing = await store.listing(created.id)
        XCTAssertTrue(listing?.edited.contains(.icon) == true)

        try await store.removeIcon(created.id)
        let removed = await store.icon(created.id)
        XCTAssertNil(removed)
        try await store.delete(created.id)
        let gone = await store.record(created.id)
        XCTAssertNil(gone)
    }
}
