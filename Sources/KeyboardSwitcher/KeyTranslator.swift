import Foundation

enum Layout: String, Codable, CaseIterable {
    case en
    case ru
    case ua

    // Full cycle order: ru → ua → en → ru.
    func next() -> Layout {
        switch self {
        case .ru: return .ua
        case .ua: return .en
        case .en: return .ru
        }
    }

    // Cycle limited to enabled layouts. If only one layout is enabled, returns
    // self (no-op). If none, returns self.
    func next(in enabled: Set<Layout>) -> Layout {
        guard enabled.count > 1, enabled.contains(self) else {
            return enabled.first ?? self
        }
        var cur = self
        for _ in 0..<Layout.allCases.count {
            cur = cur.next()
            if enabled.contains(cur) { return cur }
        }
        return self
    }
}

enum KeyTranslator {
    private static let enToRu: [Character: Character] = [
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н",
        "u": "г", "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ъ",
        "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р",
        "j": "о", "k": "л", "l": "д", ";": "ж", "'": "э",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т",
        "m": "ь", ",": "б", ".": "ю", "/": ".", "`": "ё",
        "Q": "Й", "W": "Ц", "E": "У", "R": "К", "T": "Е", "Y": "Н",
        "U": "Г", "I": "Ш", "O": "Щ", "P": "З", "{": "Х", "}": "Ъ",
        "A": "Ф", "S": "Ы", "D": "В", "F": "А", "G": "П", "H": "Р",
        "J": "О", "K": "Л", "L": "Д", ":": "Ж", "\"": "Э",
        "Z": "Я", "X": "Ч", "C": "С", "V": "М", "B": "И", "N": "Т",
        "M": "Ь", "<": "Б", ">": "Ю", "?": ",", "~": "Ё",
    ]

    private static let enToUa: [Character: Character] = [
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н",
        "u": "г", "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ї",
        "a": "ф", "s": "і", "d": "в", "f": "а", "g": "п", "h": "р",
        "j": "о", "k": "л", "l": "д", ";": "ж", "'": "є",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т",
        "m": "ь", ",": "б", ".": "ю", "/": ".", "`": "'",
        "Q": "Й", "W": "Ц", "E": "У", "R": "К", "T": "Е", "Y": "Н",
        "U": "Г", "I": "Ш", "O": "Щ", "P": "З", "{": "Х", "}": "Ї",
        "A": "Ф", "S": "І", "D": "В", "F": "А", "G": "П", "H": "Р",
        "J": "О", "K": "Л", "L": "Д", ":": "Ж", "\"": "Є",
        "Z": "Я", "X": "Ч", "C": "С", "V": "М", "B": "И", "N": "Т",
        "M": "Ь", "<": "Б", ">": "Ю", "?": ",", "~": "'",
    ]

    private static let ruToEn: [Character: Character] = invert(enToRu)
    private static let uaToEn: [Character: Character] = invert(enToUa)

    private static func invert(_ m: [Character: Character]) -> [Character: Character] {
        var out: [Character: Character] = [:]
        for (k, v) in m { out[v] = k }
        return out
    }

    // Map a character from any layout back to the canonical (en) physical-key
    // representation. Letters not in the layout's map (digits, punctuation
    // shared with en, etc.) pass through unchanged.
    private static func toEnPivot(_ ch: Character, from: Layout) -> Character {
        switch from {
        case .en: return ch
        case .ru: return ruToEn[ch] ?? ch
        case .ua: return uaToEn[ch] ?? ch
        }
    }

    private static func fromEnPivot(_ ch: Character, to: Layout) -> Character {
        switch to {
        case .en: return ch
        case .ru: return enToRu[ch] ?? ch
        case .ua: return enToUa[ch] ?? ch
        }
    }

    static func translate(_ s: String, from: Layout, to: Layout) -> String {
        guard from != to else { return s }
        var out = String()
        out.reserveCapacity(s.count)
        for ch in s {
            let pivot = toEnPivot(ch, from: from)
            out.append(fromEnPivot(pivot, to: to))
        }
        return out
    }

    static func isLatinLetter(_ ch: Character) -> Bool {
        return ch.isASCII && ch.isLetter
    }

    static func isCyrillicLetter(_ ch: Character) -> Bool {
        for scalar in ch.unicodeScalars {
            let v = scalar.value
            // Main cyrillic block plus extended chars for ru/ua specifics.
            let isBlock = (v >= 0x0410 && v <= 0x044F)
            let isExtra = v == 0x0401 || v == 0x0451 // Ё, ё
                || v == 0x0404 || v == 0x0454 // Є, є
                || v == 0x0406 || v == 0x0456 // І, і
                || v == 0x0407 || v == 0x0457 // Ї, ї
                || v == 0x0490 || v == 0x0491 // Ґ, ґ
            if isBlock || isExtra { continue }
            return false
        }
        return true
    }

    static func detectLayout(_ s: String) -> Layout? {
        var latin = 0
        var cyrillic = 0
        var ruOnly = false
        var uaOnly = false
        for ch in s {
            if isLatinLetter(ch) { latin += 1; continue }
            if !isCyrillicLetter(ch) { continue }
            cyrillic += 1
            for scalar in ch.unicodeScalars {
                switch scalar.value {
                case 0x044B, 0x042B, // ы Ы
                     0x044A, 0x042A, // ъ Ъ
                     0x044D, 0x042D, // э Э
                     0x0451, 0x0401: // ё Ё
                    ruOnly = true
                case 0x0456, 0x0406, // і І
                     0x0457, 0x0407, // ї Ї
                     0x0454, 0x0404, // є Є
                     0x0491, 0x0490: // ґ Ґ
                    uaOnly = true
                default: break
                }
            }
        }
        if latin > 0 && cyrillic == 0 { return .en }
        if cyrillic > 0 && latin == 0 {
            if ruOnly && !uaOnly { return .ru }
            if uaOnly && !ruOnly { return .ua }
            return nil
        }
        return nil
    }
}
