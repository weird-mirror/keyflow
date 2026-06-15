import XCTest
@testable import KeyboardSwitcher

final class KeyTranslatorTests: XCTestCase {
    func testEnToRu_basic() {
        XCTAssertEqual(KeyTranslator.translate("ghbdtn", from: .en, to: .ru), "привет")
        XCTAssertEqual(KeyTranslator.translate("ghbdtn vbh", from: .en, to: .ru), "привет мир")
    }

    func testRuToEn_basic() {
        XCTAssertEqual(KeyTranslator.translate("руддщ", from: .ru, to: .en), "hello")
        XCTAssertEqual(KeyTranslator.translate("црфе", from: .ru, to: .en), "what")
    }

    func testCaseAndPunctuation() {
        XCTAssertEqual(KeyTranslator.translate("Hello,", from: .en, to: .ru), "Руддщб")
        XCTAssertEqual(KeyTranslator.translate("Test.", from: .en, to: .ru), "Еуыею")
    }

    func testRoundTrip() {
        let words = ["hello", "world", "thanks", "code"]
        for w in words {
            let ru = KeyTranslator.translate(w, from: .en, to: .ru)
            let back = KeyTranslator.translate(ru, from: .ru, to: .en)
            XCTAssertEqual(back, w, "round-trip failed for \(w) → \(ru) → \(back)")
        }
    }

    func testDetectLayout() {
        XCTAssertEqual(KeyTranslator.detectLayout("hello"), .en)
        XCTAssertEqual(KeyTranslator.detectLayout("привет"), .ru)
        XCTAssertNil(KeyTranslator.detectLayout("hello мир"))
        XCTAssertNil(KeyTranslator.detectLayout("12345"))
    }
}
