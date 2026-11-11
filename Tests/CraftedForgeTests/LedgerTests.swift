//  WHAT: The ledger keeps what it is given under any key, makes a value once, and names files safely.

@testable import CraftedForge
import CraftedCore
import XCTest

final class LedgerTests: XCTestCase {
    func testKeepsMakesOnceAndForgets() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ledger-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let ledger = Ledger(folder: folder)
        try ledger.put(["a": 1], "card/src/tax.py@v1")
        XCTAssertEqual(ledger.get([String: Int].self, "card/src/tax.py@v1"), ["a": 1])
        XCTAssertNil(ledger.get([String: Int].self, "missing"))

        let made = Counter()
        for _ in 0..<3 {
            let value = try await ledger.value("plan") { () async throws -> String in made.add(); return "the plan" }
            XCTAssertEqual(value, "the plan")
        }
        XCTAssertEqual(made.value, 1)
        ledger.remove("plan")
        _ = try await ledger.value("plan") { () async throws -> String in made.add(); return "again" }
        XCTAssertEqual(made.value, 2)

        // A resumed run (a new Ledger on the same folder) reads what the first kept.
        XCTAssertEqual(Ledger(folder: folder).get(String.self, "plan"), "again")
    }

    func testSafeNames() {
        XCTAssertEqual(Ledger.safe("card/src/tax.py@v1"), "card_src_tax.py_v1")
        let long = String(repeating: "x/", count: 100)
        let safe = Ledger.safe(long)
        XCTAssertLessThanOrEqual(safe.count, 120)
        XCTAssertNotEqual(safe, Ledger.safe(long + "y"))
        XCTAssertEqual(SharedCache(root: URL(fileURLWithPath: "/c")).ledger("cards").folder.path, "/c/cards")
    }

    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func add() { lock.withLock { count += 1 } }
        var value: Int { lock.withLock { count } }
    }
}
