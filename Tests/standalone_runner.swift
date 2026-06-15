import Foundation

@main
struct TestRunner {
    static var failures: [(String, String)] = []
    static var passed = 0

    static func check(_ condition: @autoclosure () -> Bool, _ name: String, _ msg: String = "", file: String = #file, line: Int = #line) {
        if condition() {
            passed += 1
        } else {
            let detail = msg.isEmpty ? "" : " — \(msg)"
            failures.append((name, "at \(file):\(line)\(detail)"))
        }
    }

    static func eq<T: Equatable>(_ a: T, _ b: T, _ name: String, file: String = #file, line: Int = #line) {
        if a == b {
            passed += 1
        } else {
            failures.append((name, "expected \(b), got \(a) at \(file):\(line)"))
        }
    }

    static func makeDetector(en: [String], ru: [String], exceptions: [String] = []) -> LayoutDetector {
        let enDict = SetDictionary(words: Set(en))
        let ruDict = SetDictionary(words: Set(ru))
        let store = ExceptionsStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("exc-\(UUID().uuidString).json"))
        for e in exceptions { store.add(e) }
        return LayoutDetector(enDict: enDict, ruDict: ruDict, minLength: 3, exceptions: store)
    }

    static func main() {
        testKeyTranslator()
        testUaTranslator()
        testBloom()
        testDetector()
        testCycle()
        testLivePrefix()
        report()
    }

    static func testKeyTranslator() {
        eq(KeyTranslator.translate("ghbdtn", from: .en, to: .ru), "привет", "translate ghbdtn → привет")
        eq(KeyTranslator.translate("ghbdtn vbh", from: .en, to: .ru), "привет мир", "translate ghbdtn vbh")
        eq(KeyTranslator.translate("руддщ", from: .ru, to: .en), "hello", "translate руддщ → hello")
        eq(KeyTranslator.translate("црфе", from: .ru, to: .en), "what", "translate црфе → what")
        eq(KeyTranslator.translate("Hello,", from: .en, to: .ru), "Руддщб", "translate Hello,")
        eq(KeyTranslator.translate("Test.", from: .en, to: .ru), "Еуыею", "translate Test.")

        for w in ["hello", "world", "thanks", "code"] {
            let ru = KeyTranslator.translate(w, from: .en, to: .ru)
            let back = KeyTranslator.translate(ru, from: .ru, to: .en)
            eq(back, w, "round-trip \(w)")
        }

        eq(KeyTranslator.detectLayout("hello"), .en, "detectLayout hello")
        // "привет" has no chars unique to ru or ua (no ы/ъ/э/ё/і/ї/є/ґ),
        // so it's genuinely ambiguous between the two cyrillic layouts.
        check(KeyTranslator.detectLayout("привет") == nil, "detectLayout привет (ambiguous ru/ua) → nil")
        check(KeyTranslator.detectLayout("hello мир") == nil, "detectLayout mixed → nil")
        check(KeyTranslator.detectLayout("12345") == nil, "detectLayout digits → nil")
    }

    static func testUaTranslator() {
        // The Ukrainian word "привіт" is typed as "ghbdsn" (the і is at the
        // 's' position, not 't'). "ghbdtn" gives "привет" in BOTH ru and ua
        // because t→е is shared.
        eq(KeyTranslator.translate("ghbdsn", from: .en, to: .ua), "привіт", "en→ua ghbdsn → привіт")
        eq(KeyTranslator.translate("ghbdtn", from: .en, to: .ua), "привет", "en→ua ghbdtn → привет (shared chars)")
        eq(KeyTranslator.translate("привіт", from: .ua, to: .en), "ghbdsn", "ua→en привіт → ghbdsn")
        // Unique chars: ua has і (ASCII s), ru has ы at same position
        eq(KeyTranslator.translate("сидіти", from: .ua, to: .ru), "сидыти", "ua→ru сидіти → сидыти")
        eq(KeyTranslator.translate("сидыти", from: .ru, to: .ua), "сидіти", "ru→ua сидыти → сидіти")
        // ru/ua shared chars: identical after translation
        eq(KeyTranslator.translate("привет", from: .ru, to: .ua), "привет", "ru→ua привет (shared chars)")

        // Cycle order
        eq(Layout.ru.next(), .ua, "ru.next == ua")
        eq(Layout.ua.next(), .en, "ua.next == en")
        eq(Layout.en.next(), .ru, "en.next == ru")

        // Layout detection with unique chars
        eq(KeyTranslator.detectLayout("привіт"), .ua, "detectLayout ua-unique")
        eq(KeyTranslator.detectLayout("съезд"), .ru, "detectLayout ru-unique (ъ)")
        check(KeyTranslator.detectLayout("привет") == nil, "detectLayout shared cyrillic → nil")
    }

    static func testBloom() {
        let bloomWords = ["hello", "world", "thanks", "code", "swift", "macos"]
        let bloom = BloomDictionary.build(words: bloomWords, falsePositiveRate: 0.001)
        for w in bloomWords {
            check(bloom.contains(w), "bloom contains \(w)")
        }

        let inserted = (0..<5000).map { "word\($0)" }
        let bloom2 = BloomDictionary.build(words: inserted, falsePositiveRate: 0.001)
        var fps = 0
        let probes = 10_000
        for i in 0..<probes {
            if bloom2.contains("miss\(i)") { fps += 1 }
        }
        let rate = Double(fps) / Double(probes)
        check(rate < 0.01, "bloom false positive rate", "rate=\(rate)")
    }

    static func testDetector() {
        do {
            let d = makeDetector(en: ["hello"], ru: ["привет"])
            if case let .wrongLayout(corrected, target) = d.detect(word: "ghbdtn", activeLayout: .en) {
                eq(corrected, "привет", "wrongLayout ghbdtn corrected")
                eq(target, .ru, "wrongLayout ghbdtn target")
            } else {
                failures.append(("wrongLayout ghbdtn", "expected .wrongLayout"))
            }
        }

        do {
            let d = makeDetector(en: ["hello"], ru: ["привет"])
            if case let .wrongLayout(corrected, target) = d.detect(word: "руддщ", activeLayout: .ru) {
                eq(corrected, "hello", "wrongLayout руддщ corrected")
                eq(target, .en, "wrongLayout руддщ target")
            } else {
                failures.append(("wrongLayout руддщ", "expected .wrongLayout"))
            }
        }

        do {
            let d = makeDetector(en: ["hello"], ru: ["привет"])
            eq(d.detect(word: "hello", activeLayout: .en), .skip, "skip valid en")
            eq(d.detect(word: "привет", activeLayout: .ru), .skip, "skip valid ru")
        }

        do {
            let d = makeDetector(en: ["hi"], ru: ["он"])
            eq(d.detect(word: "yf", activeLayout: .en), .skip, "skip short")
        }

        do {
            let d = makeDetector(en: [], ru: [])
            eq(d.detect(word: "asdf", activeLayout: .en), .skip, "skip unknown")
        }

        do {
            let d = makeDetector(en: [], ru: ["привет"], exceptions: ["ghbdtn"])
            eq(d.detect(word: "ghbdtn", activeLayout: .en), .skip, "respect exceptions")
        }
    }

    static func testCycle() {
        // 3-language detector: input "ghbdsn" en→ua = "привіт" (in ua dict),
        // en→ru = "привыт" (not in ru dict) → only UA candidate.
        let detector = LayoutDetector(
            dicts: [
                .en: SetDictionary(words: Set(["hello"])),
                .ru: SetDictionary(words: Set([])),
                .ua: SetDictionary(words: Set(["привіт"])),
            ],
            minLength: 3,
            exceptions: nil
        )
        if case let .wrongLayout(corrected, target) = detector.detect(word: "ghbdsn", activeLayout: .en) {
            eq(corrected, "привіт", "3-lang ghbdsn corrected to UA")
            eq(target, .ua, "3-lang ghbdsn target ua")
        } else {
            failures.append(("3-lang ghbdsn", "expected .wrongLayout(.ua)"))
        }

        // Real ambiguity: word with only shared cyrillic chars present in both
        // ru and ua dicts ("мама", "тато" etc.) → skip.
        let ambDetector = LayoutDetector(
            dicts: [
                .en: SetDictionary(words: Set([])),
                .ru: SetDictionary(words: Set(["мама"])),
                .ua: SetDictionary(words: Set(["мама"])),
            ],
            minLength: 3
        )
        // "vfvf" en→ru = "мама", en→ua = "мама" — both in both dicts → ambiguous.
        eq(ambDetector.detect(word: "vfvf", activeLayout: .en), .skip, "3-lang ambiguous (мама) → skip")

        // Cycle behavior: ru→ua→en→ru, no missing layout.
        var visited: [Layout] = []
        var cur: Layout = .ru
        for _ in 0..<3 {
            visited.append(cur)
            cur = cur.next()
        }
        eq(visited, [.ru, .ua, .en], "cycle order ru→ua→en")
        eq(cur, .ru, "cycle wraps back to ru")
    }

    static func testLivePrefix() {
        // SetDictionary prefix lookup
        let en = SetDictionary(words: ["hello", "world", "help", "code"])
        check(en.hasWordWithPrefix("hel"), "prefix hel matches hello/help")
        check(en.hasWordWithPrefix("cod"), "prefix cod matches code")
        check(!en.hasWordWithPrefix("xyz"), "prefix xyz no match")
        check(!en.hasWordWithPrefix(""), "empty prefix no match")
        check(en.hasWordWithPrefix("HELLO"), "case-insensitive prefix")

        // Live detector — clear case (active en, gibberish translates to valid ru prefix)
        let detector = LayoutDetector(
            dicts: [
                .en: SetDictionary(words: ["hello"]),
                .ru: SetDictionary(words: ["привет", "приветствие", "приватный"]),
                .ua: SetDictionary(words: []),
            ],
            minLength: 3
        )
        if let r = detector.detectLivePrefix(
            buffer: "ghb", activeLayout: .en, enabledLayouts: [.en, .ru, .ua], minLength: 3
        ) {
            eq(r.target, .ru, "live ghb → ru")
            eq(r.translated, "при", "live ghb translated")
        } else {
            failures.append(("live ghb", "expected ru correction"))
        }

        // Below threshold — no correction
        check(detector.detectLivePrefix(
            buffer: "gh", activeLayout: .en, enabledLayouts: [.en, .ru, .ua], minLength: 3
        ) == nil, "below threshold → nil")

        // Active layout matches prefix — don't interrupt user
        let det2 = LayoutDetector(
            dicts: [
                .en: SetDictionary(words: ["hello"]),
                .ru: SetDictionary(words: ["хеллопер"]), // far-fetched but valid in dict
                .ua: SetDictionary(words: []),
            ],
            minLength: 3
        )
        check(det2.detectLivePrefix(
            buffer: "hel", activeLayout: .en, enabledLayouts: [.en, .ru, .ua], minLength: 3
        ) == nil, "active prefix valid → nil")

        // Disabled layout — skip even if prefix matches
        let det3 = LayoutDetector(
            dicts: [
                .en: SetDictionary(words: []),
                .ru: SetDictionary(words: ["привет"]),
                .ua: SetDictionary(words: []),
            ],
            minLength: 3
        )
        check(det3.detectLivePrefix(
            buffer: "ghb", activeLayout: .en, enabledLayouts: [.en, .ua], minLength: 3
        ) == nil, "target layout disabled → nil")

        // Multiple candidates → skip (ambiguous)
        let det4 = LayoutDetector(
            dicts: [
                .en: SetDictionary(words: []),
                .ru: SetDictionary(words: ["мама"]),
                .ua: SetDictionary(words: ["мама"]),
            ],
            minLength: 3
        )
        check(det4.detectLivePrefix(
            buffer: "vfv", activeLayout: .en, enabledLayouts: [.en, .ru, .ua], minLength: 3
        ) == nil, "ambiguous ru+ua → nil")
    }

    static func report() {
        print("=== KeyboardSwitcher tests ===")
        print("passed: \(passed)")
        print("failed: \(failures.count)")
        for (name, detail) in failures {
            print("  ✗ \(name) — \(detail)")
        }
        if failures.isEmpty {
            print("OK")
            exit(0)
        } else {
            exit(1)
        }
    }
}
