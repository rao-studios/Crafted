import Foundation
import SkeletonCore
import XCTest

/// The carried files are found where the bundle was copied, without Bundle.module.
final class CoreResourcesTests: XCTestCase {
    func testTheResourcesFolderIsFound() throws {
        XCTAssertTrue(try CoreResources.text("RESOURCES.md").contains("CoreResources"))
    }

    func testAMissingResourceIsAFailureThatSaysWhere() {
        XCTAssertThrowsError(try CoreResources.data("no-such-table.json")) { error in
            XCTAssertTrue("\(error)".contains("no-such-table.json"), "\(error)")
        }
    }
}
