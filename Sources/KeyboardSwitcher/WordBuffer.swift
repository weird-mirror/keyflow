import Foundation

final class WordBuffer {
    private(set) var characters: [Character] = []

    var isEmpty: Bool { characters.isEmpty }
    var count: Int { characters.count }
    var current: String { String(characters) }

    func append(_ ch: Character) {
        characters.append(ch)
    }

    func backspace() {
        if !characters.isEmpty { characters.removeLast() }
    }

    func reset() {
        characters.removeAll(keepingCapacity: true)
    }
}

enum WordBoundary {
    case wordChar(Character)
    case boundary
    case ignored
}

enum KeyClassifier {
    static func classify(unicodeString: String, hasModifier: Bool) -> WordBoundary {
        if hasModifier { return .boundary }
        guard let ch = unicodeString.first, unicodeString.count == 1 else { return .boundary }
        if ch.isLetter || ch == "'" || ch == "-" { return .wordChar(ch) }
        if ch.isNumber { return .wordChar(ch) }
        return .boundary
    }
}
