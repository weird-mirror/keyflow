import Foundation

enum DetectionResult: Equatable {
    case skip
    case wrongLayout(corrected: String, target: Layout)
    case ambiguous
}

struct LayoutDetector {
    let dicts: [Layout: WordDictionary]
    let minLength: Int
    let exceptions: ExceptionsStore?

    init(dicts: [Layout: WordDictionary], minLength: Int = 3, exceptions: ExceptionsStore? = nil) {
        self.dicts = dicts
        self.minLength = minLength
        self.exceptions = exceptions
    }

    // Convenience for the 2-language case (also used by tests).
    init(enDict: WordDictionary, ruDict: WordDictionary, minLength: Int = 3, exceptions: ExceptionsStore? = nil) {
        self.init(dicts: [.en: enDict, .ru: ruDict], minLength: minLength, exceptions: exceptions)
    }

    func detect(word: String, activeLayout: Layout) -> DetectionResult {
        let stripped = word.trimmingCharacters(in: .punctuationCharacters)
        guard stripped.count >= minLength else { return .skip }
        if exceptions?.contains(stripped) == true { return .skip }

        // Word is already a real word in the current keyboard layout? Leave it.
        if dicts[activeLayout]?.contains(stripped) == true { return .skip }

        var candidates: [(Layout, String)] = []
        for layout in Layout.allCases where layout != activeLayout {
            let translated = KeyTranslator.translate(stripped, from: activeLayout, to: layout)
            // Same character sequence as the input — translating into this layout
            // would be a no-op (ru/ua often produce identical text). Not useful
            // as a correction signal.
            if translated == stripped { continue }
            if dicts[layout]?.contains(translated) == true {
                candidates.append((layout, translated))
            }
        }

        if candidates.count == 1 {
            return .wrongLayout(corrected: candidates[0].1, target: candidates[0].0)
        }
        return .skip
    }

    // Live detection: called on every typed char (after a minimum length).
    // Returns a correction iff:
    //   - the buffer is not a valid prefix in the active layout's dict
    //   - exactly one other enabled layout has a word that starts with the
    //     translated buffer, and the translation actually changes the string
    //
    // The "not a prefix in active dict" guard is what stops the feature from
    // hijacking normal typing.
    func detectLivePrefix(
        buffer: String,
        activeLayout: Layout,
        enabledLayouts: Set<Layout>,
        minLength: Int
    ) -> (target: Layout, translated: String)? {
        let stripped = buffer.trimmingCharacters(in: .punctuationCharacters)
        guard stripped.count >= minLength else { return nil }
        if exceptions?.contains(stripped) == true { return nil }

        if dicts[activeLayout]?.hasWordWithPrefix(stripped) == true { return nil }

        var candidates: [(Layout, String)] = []
        for layout in Layout.allCases where layout != activeLayout {
            guard enabledLayouts.contains(layout) else { continue }
            let translated = KeyTranslator.translate(stripped, from: activeLayout, to: layout)
            if translated == stripped { continue }
            if dicts[layout]?.hasWordWithPrefix(translated) == true {
                candidates.append((layout, translated))
            }
        }

        if candidates.count == 1 {
            return (candidates[0].0, candidates[0].1)
        }
        return nil
    }
}
