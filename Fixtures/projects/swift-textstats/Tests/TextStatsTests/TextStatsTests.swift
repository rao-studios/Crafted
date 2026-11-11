import XCTest
@testable import TextStats

final class TextStatsTests: XCTestCase {
    func testCounts() {
        let stats = TextStats("The cat sat on the mat. It was happy!")
        XCTAssertEqual(stats.words, 9)
        XCTAssertEqual(stats.sentences, 2)
    }

    func testSyllables() {
        XCTAssertEqual(TextStats.syllables(in: "happy"), 2)
        XCTAssertEqual(TextStats.syllables(in: "make"), 1)
    }

    func testMinutes() {
        XCTAssertEqual(TextStats(String(repeating: "word ", count: 238)).minutes, 1, accuracy: 0.0001)
    }
}
