import Carbon
import Foundation

struct HotkeySpec: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static func parse(_ s: String) -> HotkeySpec? {
        let tokens = s.lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !tokens.isEmpty else { return nil }

        var mods: UInt32 = 0
        var keyName: String?

        for (i, t) in tokens.enumerated() {
            switch t {
            case "cmd", "command", "meta": mods |= UInt32(cmdKey)
            case "ctrl", "control":        mods |= UInt32(controlKey)
            case "opt", "alt", "option":   mods |= UInt32(optionKey)
            case "shift":                  mods |= UInt32(shiftKey)
            default:
                guard i == tokens.count - 1 else { return nil }
                keyName = t
            }
        }
        guard let k = keyName, let code = keyCodeForName(k) else { return nil }
        return HotkeySpec(keyCode: code, modifiers: mods)
    }

    func describe() -> String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey)     != 0 { parts.append("cmd") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("ctrl") }
        if modifiers & UInt32(optionKey)  != 0 { parts.append("opt") }
        if modifiers & UInt32(shiftKey)   != 0 { parts.append("shift") }
        parts.append(HotkeySpec.nameForKeyCode(keyCode) ?? "kc\(keyCode)")
        return parts.joined(separator: "+")
    }

    private static let nameToCode: [String: UInt32] = [
        "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9),
        "f1":  UInt32(kVK_F1),  "f2":  UInt32(kVK_F2),  "f3":  UInt32(kVK_F3),
        "f4":  UInt32(kVK_F4),  "f5":  UInt32(kVK_F5),  "f6":  UInt32(kVK_F6),
        "f7":  UInt32(kVK_F7),  "f8":  UInt32(kVK_F8),  "f9":  UInt32(kVK_F9),
        "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
        "f13": UInt32(kVK_F13), "f14": UInt32(kVK_F14), "f15": UInt32(kVK_F15),
        "f16": UInt32(kVK_F16), "f17": UInt32(kVK_F17), "f18": UInt32(kVK_F18),
        "f19": UInt32(kVK_F19),
        "space":    UInt32(kVK_Space),
        "return":   UInt32(kVK_Return),
        "enter":    UInt32(kVK_Return),
        "tab":      UInt32(kVK_Tab),
        "escape":   UInt32(kVK_Escape),
        "esc":      UInt32(kVK_Escape),
        "delete":   UInt32(kVK_Delete),
        "backspace": UInt32(kVK_Delete),
        "forwarddelete": UInt32(kVK_ForwardDelete),
        ",":  UInt32(kVK_ANSI_Comma),
        ".":  UInt32(kVK_ANSI_Period),
        "/":  UInt32(kVK_ANSI_Slash),
        ";":  UInt32(kVK_ANSI_Semicolon),
        "'":  UInt32(kVK_ANSI_Quote),
        "[":  UInt32(kVK_ANSI_LeftBracket),
        "]":  UInt32(kVK_ANSI_RightBracket),
        "-":  UInt32(kVK_ANSI_Minus),
        "=":  UInt32(kVK_ANSI_Equal),
        "`":  UInt32(kVK_ANSI_Grave),
        "\\": UInt32(kVK_ANSI_Backslash),
    ]

    private static func keyCodeForName(_ name: String) -> UInt32? {
        return nameToCode[name]
    }

    private static func nameForKeyCode(_ code: UInt32) -> String? {
        return nameToCode.first { $0.value == code }?.key
    }
}
