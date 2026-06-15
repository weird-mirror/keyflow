import XCTest
@testable import KeyboardSwitcher

final class LayoutDetectorTests: XCTestCase {
    private func makeDetector(en: [String], ru: [String], exceptions: [String] = []) -> LayoutDetector {
        let enDict = SetDictionary(words: Set(en))
        let ruDict = SetDictionary(words: Set(ru))
        let store = ExceptionsStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("exc-\(UUID().uuidString).json"))
        for e in exceptions { store.add(e) }
        return LayoutDetector(enDict: enDict, ruDict: ruDict, minLength: 3, exceptions: store)
    }

    func testDetectsWrongLayoutEnTypedAsRu() {
        let d = makeDetector(en: ["hello"], ru: ["привет"])
        let res = d.detect(word: "ghbdtn", activeLayout: .en)
        switch res {
        case .wrongLayout(let corrected, let target):
            XCTAssertEqual(corrected, "привет")
            XCTAssertEqual(target, .ru)
        default:
            XCTFail("expected .wrongLayout, got \(res)")
        }
    }

    func testDetectsWrongLayoutRuTypedAsEn() {
        let d = makeDetector(en: ["hello"], ru: ["привет"])
        let res = d.detect(word: "руддщ", activeLayout: .ru)
        switch res {
        case .wrongLayout(let corrected, let target):
            XCTAssertEqual(corrected, "hello")
            XCTAssertEqual(target, .en)
        default:
            XCTFail("expected .wrongLayout, got \(res)")
        }
    }

    func testSkipsValidEnglish() {
        let d = makeDetector(en: ["hello"], ru: ["привет"])
        XCTAssertEqual(d.detect(word: "hello", activeLayout: .en), .skip)
    }

    func testSkipsValidRussian() {
        let d = makeDetector(en: ["hello"], ru: ["привет"])
        XCTAssertEqual(d.detect(word: "привет", activeLayout: .ru), .skip)
    }

    func testSkipsShortWords() {
        let d = makeDetector(en: ["hi"], ru: ["он"])
        XCTAssertEqual(d.detect(word: "yf", activeLayout: .en), .skip)
    }

    func testSkipsUnknown() {
        let d = makeDetector(en: [], ru: [])
        XCTAssertEqual(d.detect(word: "asdf", activeLayout: .en), .skip)
    }

    func testRespectsExceptions() {
        let d = makeDetector(en: [], ru: ["привет"], exceptions: ["ghbdtn"])
        XCTAssertEqual(d.detect(word: "ghbdtn", activeLayout: .en), .skip)
    }
}
