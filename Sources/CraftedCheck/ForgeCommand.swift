//  WHAT: `crafted-check forge`: one generation end to end, headless. A Forge on the scripted model, the live
//        toolchain and the repository's templates, in a home of its own (a fresh temporary folder unless --home),
//        every event printed as a line, every question answered with its default, the interpretation picked by
//        --choose, and with --zip the archive written as the Download button writes it.
//  OUT:  Exit 0 only when the run completed with every gate passed or skipped (and the zip, when asked, was written);
//        1 when it failed or a gate failed; 2 when it could not start.

import CraftedCore
import CraftedForge
import CraftedToolchain
import Foundation

enum ForgeCommand {
    static let usage = """
    crafted-check forge --role engineer|designer --models scripted [--choose N] [--auto] [--home DIR] [--zip OUT.zip]
                        [--no-install] [--no-build] [--credit NAME] <folder>
      --choose N    the interpretation to take, 1 to 3 (default 1)
      --auto        answer every question with its default (always on: there is no one to ask)
      --home DIR    where generations are kept (default: a fresh temporary folder)
      --zip OUT     after a clean run, write the downloadable archive there
    """

    static func run(_ arguments: CheckArguments) async -> Int32 {
        guard let roleName = arguments.value("role"), let role = CraftedRole(rawValue: roleName) else {
            return fail("Say --role engineer or --role designer.\n\n" + usage)
        }
        switch arguments.value("models") ?? "scripted" {
        case "scripted": break
        case "live":
            print("Live models are not wired into crafted-check in this pass: use --models scripted.")
            return 2
        case let other:
            return fail("--models is scripted or live, not \(other).")
        }
        let folder: URL
        do { folder = try arguments.folder() } catch { return fail("\(error)\n\n" + usage) }
        guard FileManager.default.fileExists(atPath: folder.path) else { return fail("There is no folder at \(folder.path).") }
        guard let scripts = ScriptedModel.locateScripts() else {
            return fail("No Fixtures/scripts folder was found above here or the executable; set CRAFTED_SCRIPTS.")
        }
        guard let templates = TemplateSource.locate() else {
            return fail("No Templates folder was found above here or the executable; set CRAFTED_TEMPLATES.")
        }
        let home = arguments.value("home").map(CheckArguments.url)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("crafted-check-\(UUID().uuidString.prefix(8))", isDirectory: true)

        let choice = arguments.value("choose").flatMap(Int.init).map { max($0 - 1, 0) } ?? 0
        var options = ForgeOptions(credit: arguments.value("credit") ?? (role == .designer ? "Crafted Check" : nil),
                                   autoDecide: true, autoChoose: choice)
        options.install = !arguments.has("no-install")
        options.build = !arguments.has("no-build")

        let forge = Forge(model: ScriptedModel(scripts: scripts), toolchain: SwiftToolchain(), templates: templates,
                          store: GenerationStore(home: CraftedHome(root: home)))
        print("[check] \(role.title.lowercased()) · \(folder.path) · scripts \(scripts.path) · templates \(templates.root.path) · home \(home.path)")

        let run: ForgeRun
        do {
            run = try await forge.start(folder: folder, role: role, options: options)
        } catch {
            return fail("The run did not start: \(error.localizedDescription)")
        }
        Interrupt.onInterrupt { Task { await run.cancel() } }
        let ended = Ended()
        let printer = Task {
            var line = EventLine()
            for await event in run.events {
                print(line.text(event))
                switch event {
                case .completed(let report): ended.report = report
                case .failed, .cancelled: ended.stopped = true
                default: break
                }
            }
        }
        await run.start()
        await run.wait()
        await printer.value

        guard let report = ended.report else { return 1 }
        guard report.passed else {
            print("[check] a gate failed: " + report.failedGates.map(\.name).joined(separator: ", "))
            return 1
        }
        if let zip = arguments.value("zip").map(CheckArguments.url) {
            do {
                let (exported, archive) = try await forge.export(run.id, to: .zip(zip), options: options)
                let size = (try? FileManager.default.attributesOfItem(atPath: archive.path)[.size] as? NSNumber)?.intValue ?? 0
                print("[zip] \(archive.path) · \(exported.fileCount) files · \(size / 1024) KB")
            } catch {
                print("[zip] the archive was not written: \(error.localizedDescription)")
                return 1
            }
        }
        print("[check] passed: generation \(run.id)")
        return 0
    }

    static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        return 2
    }

    /// How the run ended, as the event loop saw it.
    final class Ended: @unchecked Sendable {
        var report: PackageReport?
        var stopped = false
    }
}
