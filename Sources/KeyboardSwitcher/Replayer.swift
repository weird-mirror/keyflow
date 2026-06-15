import CoreGraphics
import Foundation

// Distinguishes events we synthesize so EventTap callback can ignore them.
let kSyntheticMarker: Int64 = 0x4B425357_5F5F4D52 // "KBSW__MR"

enum Replayer {
    // Use privateState so the source doesn't carry the user's current modifier
    // flags. Otherwise a held-down Cmd (from Cmd+Z) would turn our synthetic
    // backspaces into Cmd+Backspace (= delete-to-line-start in many apps).
    private static func makeSource() -> CGEventSource? {
        return CGEventSource(stateID: .privateState)
    }

    private static func mark(_ event: CGEvent) {
        event.flags = []
        event.setIntegerValueField(.eventSourceUserData, value: kSyntheticMarker)
    }

    static func sendBackspaces(count: Int) {
        guard count > 0 else { return }
        let source = makeSource()
        for _ in 0..<count {
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true) {
                mark(down)
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) {
                mark(up)
                up.post(tap: .cghidEventTap)
            }
        }
    }

    static func typeString(_ s: String) {
        let source = makeSource()
        for scalar in s.unicodeScalars {
            var ch = UniChar(scalar.value)
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
                mark(down)
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
                mark(up)
                up.post(tap: .cghidEventTap)
            }
        }
    }

    static func isSynthetic(_ event: CGEvent) -> Bool {
        return event.getIntegerValueField(.eventSourceUserData) == kSyntheticMarker
    }
}
