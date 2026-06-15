import XCTest
@testable import KeyboardSwitcher

final class BloomDictionaryTests: XCTestCase {
    func testContainsAllInsertedWords() {
        let words = ["hello", "world", "thanks", "code", "swift", "macos"]
        let bloom = BloomDictionary.build(words: words, falsePositiveRate: 0.001)
        for w in words {
            XCTAssertTrue(bloom.contains(w), "missing inserted word \(w)")
        }
    }

    func testLowFalsePositiveRate() {
        let inserted = (0..<5000).map { "word\($0)" }
        let bloom = BloomDictionary.build(words: inserted, falsePositiveRate: 0.001)

        var fps = 0
        let probes = 10_000
        for i in 0..<probes {
            let candidate = "miss\(i)"
            if bloom.contains(candidate) { fps += 1 }
        }
        let rate = Double(fps) / Double(probes)
        XCTAssertLessThan(rate, 0.01, "false positive rate too high: \(rate)")
    }
}
