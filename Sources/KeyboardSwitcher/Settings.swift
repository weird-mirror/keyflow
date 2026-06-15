import Foundation

struct Settings: Codable {
    var enabled: Bool = true
    var autoCorrectOnBoundary: Bool = true
    var minWordLength: Int = 3
    var disabledBundleIDs: Set<String> = []
    var enabledLayouts: Set<Layout> = [.en, .ru, .ua]
    var skipSecureFields: Bool = true
    var hotkeyKeyCode: UInt32? = nil
    var hotkeyModifiers: UInt32 = 0
    var tapModifier: String? = "cmd"
    var tapWindowSeconds: Double = 0.5
    var launchAtLogin: Bool = false
    var showInDock: Bool = true
    var liveAutoCorrect: Bool = true
    var liveAutoCorrectMinLength: Int = 3

    init() {}

    enum CodingKeys: String, CodingKey {
        case enabled, autoCorrectOnBoundary, minWordLength
        case disabledBundleIDs, enabledLayouts
        case skipSecureFields, hotkeyKeyCode, hotkeyModifiers
        case tapModifier, tapWindowSeconds, launchAtLogin, showInDock
        case liveAutoCorrect, liveAutoCorrectMinLength
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var s = Settings()
        if let v = try c.decodeIfPresent(Bool.self, forKey: .enabled) { s.enabled = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .autoCorrectOnBoundary) { s.autoCorrectOnBoundary = v }
        if let v = try c.decodeIfPresent(Int.self, forKey: .minWordLength) { s.minWordLength = v }
        if let v = try c.decodeIfPresent(Set<String>.self, forKey: .disabledBundleIDs) { s.disabledBundleIDs = v }
        if let v = try c.decodeIfPresent(Set<Layout>.self, forKey: .enabledLayouts) { s.enabledLayouts = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .skipSecureFields) { s.skipSecureFields = v }
        s.hotkeyKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .hotkeyKeyCode)
        if let v = try c.decodeIfPresent(UInt32.self, forKey: .hotkeyModifiers) { s.hotkeyModifiers = v }
        s.tapModifier = try c.decodeIfPresent(String.self, forKey: .tapModifier)
        if let v = try c.decodeIfPresent(Double.self, forKey: .tapWindowSeconds) { s.tapWindowSeconds = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) { s.launchAtLogin = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .showInDock) { s.showInDock = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .liveAutoCorrect) { s.liveAutoCorrect = v }
        if let v = try c.decodeIfPresent(Int.self, forKey: .liveAutoCorrectMinLength) { s.liveAutoCorrectMinLength = v }
        self = s
    }

    static func defaultURL() -> URL {
        let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? FileManager.default.temporaryDirectory).appendingPathComponent("KeyFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    static func load() -> Settings {
        guard let data = try? Data(contentsOf: defaultURL()),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings()
        }
        return s
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Settings.defaultURL(), options: .atomic)
    }

    // Blacklist semantics: an app is allowed unless it's in disabledBundleIDs.
    // Apps with no bundle ID (rare CLI helpers) are skipped to be safe.
    func appAllowed(_ bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return !disabledBundleIDs.contains(id)
    }
}
