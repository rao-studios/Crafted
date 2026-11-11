//  WHAT: The app's flow, proven without a click: with CRAFTED_SELFTEST=<fixture folder> the app drives its real services
//        headlessly through the root: a forge run (designer for Fixtures/design/*, engineer for Fixtures/projects/*,
//        choosing interpretation 0 and answering every question with its default), waits for it to finish, saves an
//        edited listing (a new tagline), sets an icon from a picture in the fixture, downloads the zip, opens the zip to
//        check the listing and icon went in, prints a summary and exits 0 or 1.
//  IN:   CRAFTED_SELFTEST (the fixture), CRAFTED_MODELS=scripted, CRAFTED_HOME (a temporary home), optionally
//        CRAFTED_SELFTEST_OUT (where the zip goes; a temporary folder otherwise), CRAFTED_SELFTEST_ROLE (designer or
//        engineer, when the path does not say), CRAFTED_SELFTEST_TIMEOUT (seconds, default 1800).
//  OUT:  stdout; the exit status.
//  PIN:  THE REAL STACK. The same root, services, forge, store and zip the windows use; no window opens (the app runs
//        with the `.prohibited` activation policy) and the person's preferences are untouched (PreferencesService
//        keeps its own key under a self-test).

import AppKit
import CraftedCore
import CraftedForge
import CraftedRuntime
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
enum SelfTest {
    nonisolated static var isRequested: Bool {
        !(ProcessInfo.processInfo.environment["CRAFTED_SELFTEST"] ?? "").isEmpty
    }

    static func run(_ root: CraftedAppRoot) {
        Task { @MainActor in
            let code = await drive(root)
            fflush(stdout)
            exit(code)
        }
    }

    // MARK: - The drive

    static func drive(_ root: CraftedAppRoot) async -> Int32 {
        let environment = ProcessInfo.processInfo.environment
        let fixture = URL(fileURLWithPath: ((environment["CRAFTED_SELFTEST"] ?? "") as NSString).expandingTildeInPath,
                          isDirectory: true).standardizedFileURL
        let timeout = Double(environment["CRAFTED_SELFTEST_TIMEOUT"] ?? "") ?? 1800
        say("crafted self-test")
        say("  fixture   \(fixture.path)")
        say("  home      \(CraftedHome.standard.root.path)")
        say("  models    \(root.runtime.modelChoice.title)")
        say("  templates \(TemplateSource.locate()?.root.path ?? "none found")")
        guard FileManager.default.fileExists(atPath: fixture.path) else { return fail("no folder at \(fixture.path)") }
        guard let role = role(for: fixture, environment) else {
            return fail("say which role: the path has no design/ or projects/ in it, and CRAFTED_SELFTEST_ROLE is not set")
        }
        if !root.runtime.modelChoice.isScripted { say("  warning: CRAFTED_MODELS is not `scripted`: the live models would load") }

        // The person, as the onboarding and Settings would set them.
        await root.waitForPreferences()
        root.preferences.set(.role(role))
        root.preferences.set(.creditName("Crafted Self-Test"))
        root.environment.set(.onboarding(.open))
        let statuses = await root.models.refresh()
        _ = await root.library.refresh()
        say("  role      \(role.rawValue)")
        say("  on disk   " + statuses.map { "\($0.kind.rawValue) \($0.installed ? "yes" : "no")\($0.installed && !$0.matchesPin ? " (another commit)" : "")" }
            .joined(separator: ", ") + " (read, never loaded)")

        // The run, as Home's Start does it, choosing the first interpretation and taking every default.
        let options = root.runOptions(autoDecide: true, autoChoose: 0)
        let started = Date()
        let id: String
        do {
            id = try await root.forge.start(folder: fixture, role: role, options: options)
        } catch {
            return fail("the run did not start: \(error.localizedDescription)")
        }
        root.environment.set(.route(.generation(id)))
        say("▸ generation \(id)")
        guard let run = await follow(root, id: id, timeout: timeout) else {
            return fail("the run did not end within \(Int(timeout)) s")
        }
        say(String(format: "▸ run ended: %@ in %.1f s", run.phase.rawValue, Date().timeIntervalSince(started)))
        // The listing and the icon do not wait for the run: the form saves them mid-run too. They are proven either way.
        let written: AgentListing
        switch await editListingAndIcon(root, id: id, role: role, fixture: fixture) {
        case .success(let listing): written = listing
        case .failure(let reason): return fail(reason.text)
        }
        guard run.phase == .done, let built = run.report else {
            return fail("the run \(run.phase.rawValue): \(run.failure?.reason ?? "no report") (the listing and icon steps passed)")
        }
        say("  package   \(built.identity.package) (@\(built.identity.word)), \(built.fileCount) files, built here: \(built.built)")
        for gate in built.gates { say("  gate      \(gate.name): \(gate.skipped ? "skipped" : gate.passed ? "passed" : "FAILED")") }

        // The download, as the listing page's button does it.
        let out = environment["CRAFTED_SELFTEST_OUT"].map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("crafted-selftest-\(UUID().uuidString.prefix(8))")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let archive = out.appendingPathComponent(written.identity.package + ".zip")
        let report: PackageReport
        do {
            (report, _) = try await root.forge.export(id, to: archive, options: options)
        } catch {
            return fail("the download failed: \(error.localizedDescription)")
        }
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: archive.path))?[.size] as? NSNumber)?.intValue ?? 0
        say("▸ zip \(archive.path) (\(bytes.formatted()) bytes)")

        // What went in: the listing as saved, and the icon.
        let listingPath = "\(report.identity.package)/Assets/listing.json"
        guard let stored = unzip(archive, listingPath).flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) else {
            return fail("the zip has no \(listingPath)")
        }
        guard stored["tagline"] as? String == written.tagline else { return fail("the zip's listing.json does not carry the new tagline") }
        guard let icon = unzip(archive, "\(report.identity.package)/Assets/icon.png"), !icon.isEmpty else {
            return fail("the zip has no Assets/icon.png")
        }
        _ = await root.library.refresh()
        let record = root.library.state.generation(id)
        say("▸ checked: listing.json carries the new tagline, icon.png is \(icon.count.formatted()) bytes")
        say("")
        say("summary")
        say("  generation  \(id)")
        say("  role        \(role.rawValue)")
        say("  stages      \(run.stages.map(\.id).joined(separator: " → "))")
        say("  package     \(report.identity.package), word @\(report.identity.word), \(report.fileCount) files")
        say("  gates       \(report.gates.map { "\($0.name)=\($0.skipped ? "skipped" : $0.passed ? "pass" : "FAIL")" }.joined(separator: " "))")
        say("  status      \(record?.status.rawValue ?? "?"), last download \(record?.lastExport.map { $0.formatted() } ?? "none")")
        say("  zip         \(archive.path)")
        say("PASS")
        return 0
    }

    // MARK: - Pieces

    struct Failure: Error { let text: String }

    /// The listing, as the form saves it (a new tagline, marked edited), and the icon, as the well takes it.
    static func editListingAndIcon(_ root: CraftedAppRoot, id: String, role: CraftedRole, fixture: URL) async -> Result<AgentListing, Failure> {
        _ = await root.library.refresh()
        guard let saved = root.library.state.listings[id] else { return .failure(Failure(text: "no listing.json for \(id)")) }
        var draft = saved
        draft.tagline = "Made by Crafted's self-test on \(Date().formatted(date: .abbreviated, time: .omitted))."
        let written: AgentListing
        do {
            written = try await root.library.saveListing(LibraryOps.marking(draft, against: saved), for: id)
        } catch {
            return .failure(Failure(text: "the listing did not save: \(error.localizedDescription)"))
        }
        guard written.tagline == draft.tagline, written.edited.contains(.tagline) else {
            return .failure(Failure(text: "the saved listing lost the tagline or its edited mark"))
        }
        let problems = ListingRules.problems(written, role: role)
        say("▸ listing saved: \"\(written.name)\" (@\(written.word)), tagline edited; \(problems.isEmpty ? "valid" : problems.map(\.message).joined(separator: " "))")
        do {
            let picture = try iconSource(in: fixture)
            try await root.library.setIcon(from: picture, for: id)
            _ = await root.library.refresh()
            guard root.library.state.icons[id] != nil, root.library.state.listings[id]?.edited.contains(.icon) == true else {
                return .failure(Failure(text: "the icon was set but the library does not show it"))
            }
            say("▸ icon set from \(picture.lastPathComponent), normalised to a square 1024 px PNG")
        } catch {
            return .failure(Failure(text: "the icon was not set: \(error.localizedDescription)"))
        }
        return .success(written)
    }

    /// The run until it ends, printing each stage as it starts.
    static func follow(_ root: CraftedAppRoot, id: String, timeout: Double) async -> LiveRun? {
        let deadline = Date().addingTimeInterval(timeout)
        var said = Swift.Set<String>()
        var lastDetail = Date.distantPast
        while Date() < deadline {
            if let run = root.forge.state.live(id) {
                if let stage = run.currentStage, said.insert(stage.id).inserted {
                    say("  stage     \(stage.title)")
                }
                if let detail = run.progress?.detail, Date().timeIntervalSince(lastDetail) > 5, run.phase.isLive {
                    say("            \(detail.prefix(110))")
                    lastDetail = Date()
                }
                if !run.phase.isLive { return run }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    static func role(for fixture: URL, _ environment: [String: String]) -> CraftedRole? {
        if let named = environment["CRAFTED_SELFTEST_ROLE"].flatMap(CraftedRole.init(rawValue:)) { return named }
        let parts = fixture.pathComponents
        if parts.contains("design") { return .designer }
        if parts.contains("projects") { return .engineer }
        return nil
    }

    /// A picture in the fixture (the first PNG or JPEG), else one drawn here.
    static func iconSource(in fixture: URL) throws -> URL {
        let pictures: Swift.Set<String> = ["png", "jpg", "jpeg"]
        if let walker = FileManager.default.enumerator(at: fixture, includingPropertiesForKeys: nil) {
            for case let url as URL in walker where pictures.contains(url.pathExtension.lowercased()) {
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 { return url }
            }
        }
        let side = 640
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw IconNormaliser.Failure.unreadable("drawn") }
        context.setFillColor(CGColor(srgbRed: 0.99, green: 0.98, blue: 0.96, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(CGColor(srgbRed: 0.68, green: 0.56, blue: 0.38, alpha: 1))
        context.fillEllipse(in: CGRect(x: 120, y: 120, width: 400, height: 400))
        guard let image = context.makeImage() else { throw IconNormaliser.Failure.unreadable("drawn") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("crafted-selftest-icon-\(UUID().uuidString.prefix(6)).png")
        try IconNormaliser.pngData(image).write(to: url)
        return url
    }

    /// One file out of a zip, by its path inside.
    static func unzip(_ archive: URL, _ path: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archive.path, path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    static func say(_ line: String) {
        print(line)
        fflush(stdout)
    }

    static func fail(_ reason: String) -> Int32 {
        say("FAIL: \(reason)")
        return 1
    }
}
