//  WHAT: Every generation on disk, and the one place their files are written: the record, the listing, the icon.
//        The forge writes its progress and suggestions through it; the library reads and the form saves through it.
//  OUT:  LibraryService (the grid, the form), the forge (status, stage, the listing it suggests).
//  PIN:  ONE WRITER PER PROCESS. An actor, shared (`shared`), so a run finishing while the person saves the form never
//        interleaves two writes of listing.json. Disk is the truth: the grid is a read of this folder.
//  PIN:  EVERY WRITE IS ATOMIC (temp then rename): a crash leaves the last good file, never half of one.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public actor GenerationStore {
    public static let shared = GenerationStore(home: .standard)

    public nonisolated let home: CraftedHome

    public init(home: CraftedHome) { self.home = home }

    // MARK: Paths

    public nonisolated func folder(_ id: String) -> URL { home.generation(id) }
    public nonisolated func recordURL(_ id: String) -> URL { folder(id).appendingPathComponent("generation.json") }
    public nonisolated func listingURL(_ id: String) -> URL { folder(id).appendingPathComponent("listing.json") }
    public nonisolated func iconURL(_ id: String) -> URL { folder(id).appendingPathComponent("icon.png") }
    /// The forge's own folder: ledger, artefacts, events, work trees.
    public nonisolated func runURL(_ id: String) -> URL { folder(id).appendingPathComponent("run", isDirectory: true) }
    /// The last assembled clean package lives in here, as <Package>/.
    public nonisolated func packageURL(_ id: String) -> URL { folder(id).appendingPathComponent("package", isDirectory: true) }

    // MARK: Records

    /// Every generation, newest change first.
    public func list() -> [Generation] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: home.generations, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { record($0.lastPathComponent) }.sorted { $0.updated > $1.updated }
    }

    public func record(_ id: String) -> Generation? {
        guard let data = try? Data(contentsOf: recordURL(id)) else { return nil }
        return try? Self.decoder.decode(Generation.self, from: data)
    }

    /// A new generation for a dropped folder, with a first listing from its name.
    public func create(role: CraftedRole, source: URL, credit: String?) throws -> Generation {
        let id = UUID().uuidString.lowercased()
        let generation = Generation(id: id, role: role, source: source.standardizedFileURL.path)
        try FileManager.default.createDirectory(at: runURL(id), withIntermediateDirectories: true)
        try write(generation)
        try write(listing: AgentListing.placeholder(folderName: source.lastPathComponent, role: role, credit: credit), id)
        return generation
    }

    /// Changes a record and stamps `updated`. Nil when there is no such generation.
    @discardableResult
    public func update(_ id: String, _ change: (inout Generation) -> Void) throws -> Generation? {
        guard var generation = record(id) else { return nil }
        change(&generation)
        generation.updated = Date()
        try write(generation)
        return generation
    }

    public func delete(_ id: String) throws {
        let url = folder(id)
        guard url.path.hasPrefix(home.generations.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: Listing

    public func listing(_ id: String) -> AgentListing? {
        guard let data = try? Data(contentsOf: listingURL(id)) else { return nil }
        return try? Self.decoder.decode(AgentListing.self, from: data)
    }

    /// The person's save: the form's values, with the keys they changed marked edited.
    public func saveListing(_ listing: AgentListing, _ id: String) throws {
        try write(listing: listing, id)
        try update(id) { $0.identity = listing.identity }
    }

    /// The forge's suggestion, merged under the person's edits. Answers the listing as it now stands.
    @discardableResult
    public func suggestListing(_ suggestion: AgentListing, _ id: String) throws -> AgentListing {
        let current = listing(id) ?? suggestion
        let merged = current.merging(suggestion: suggestion)
        try write(listing: merged, id)
        try update(id) { $0.identity = merged.identity }
        return merged
    }

    // MARK: Icon

    public func icon(_ id: String) -> URL? {
        FileManager.default.fileExists(atPath: iconURL(id).path) ? iconURL(id) : nil
    }

    /// Any picture the person chose, made into the store's icon: a square 1024 px PNG, centre-cropped.
    public func setIcon(from image: URL, _ id: String) throws {
        let png = try IconNormaliser.squarePNG(from: image, side: 1024)
        try AtomicFile.write(png, to: iconURL(id))
        try update(id) { _ in }
        if var listing = listing(id) {
            listing.edited.insert(.icon)
            try write(listing: listing, id)
        }
    }

    public func removeIcon(_ id: String) throws {
        try? FileManager.default.removeItem(at: iconURL(id))
        try update(id) { _ in }
    }

    // MARK: Writing

    private func write(_ generation: Generation) throws {
        try AtomicFile.write(try Self.encoder.encode(generation), to: recordURL(generation.id))
    }

    private func write(listing: AgentListing, _ id: String) throws {
        try AtomicFile.write(try Self.encoder.encode(listing), to: listingURL(id))
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// A picture as the store's icon: square, centre-cropped, PNG.
public enum IconNormaliser {
    public enum Failure: Error, LocalizedError {
        case unreadable(String)
        public var errorDescription: String? {
            switch self { case .unreadable(let name): return "\(name) is not a picture Crafted can read." }
        }
    }

    public static func squarePNG(from url: URL, side: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { throw Failure.unreadable(url.lastPathComponent) }
        return try squarePNG(image, side: side)
    }

    public static func squarePNG(_ image: CGImage, side: Int) throws -> Data {
        let edge = min(image.width, image.height)
        let crop = CGRect(x: (image.width - edge) / 2, y: (image.height - edge) / 2, width: edge, height: edge)
        guard let square = image.cropping(to: crop),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw Failure.unreadable("The picture") }
        context.interpolationQuality = .high
        context.draw(square, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let scaled = context.makeImage() else { throw Failure.unreadable("The picture") }
        return try pngData(scaled)
    }

    public static func pngData(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.unreadable("The picture")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.unreadable("The picture") }
        return data as Data
    }
}
