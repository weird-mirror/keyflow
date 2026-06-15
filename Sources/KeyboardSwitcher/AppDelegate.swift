import AppKit
import ApplicationServices
import Combine
import Foundation

final class AppState: ObservableObject {
    @Published var settings: Settings
    @Published var axGranted: Bool
    @Published var secureInputActive: Bool = false

    let exceptions: ExceptionsStore
    var coordinator: Coordinator?
    var tap: EventTap?
    var hotkey: HotkeyManager?

    init() {
        self.settings = Settings.load()
        self.exceptions = ExceptionsStore(url: ExceptionsStore.defaultURL())
        self.axGranted = AppContext.hasAccessibilityPermission(prompt: false)
    }

    func persist() {
        settings.save()
        coordinator?.update(settings: settings)
        rewireHotkey()
    }

    func setBlacklist(_ ids: Set<String>) {
        settings.disabledBundleIDs = ids
        persist()
    }

    func setLayout(_ layout: Layout, enabled: Bool) {
        if enabled { settings.enabledLayouts.insert(layout) }
        else { settings.enabledLayouts.remove(layout) }
        persist()
    }

    func setTapModifier(_ name: String?) {
        settings.tapModifier = name
        settings.hotkeyKeyCode = nil
        settings.hotkeyModifiers = 0
        persist()
    }

    func setLaunchAtLogin(_ on: Bool) {
        if let err = LaunchAtLogin.setEnabled(on) {
            NSLog("LaunchAtLogin error: \(err.localizedDescription)")
        }
        settings.launchAtLogin = LaunchAtLogin.isEnabled
        persist()
    }

    func setShowInDock(_ on: Bool) {
        settings.showInDock = on
        persist()
        NSApp.setActivationPolicy(on ? .regular : .accessory)
        if on { NSApp.activate(ignoringOtherApps: true) }
    }

    func clearExceptions() {
        let url = ExceptionsStore.defaultURL()
        try? FileManager.default.removeItem(at: url)
    }

    func refreshAXStatus() {
        axGranted = AppContext.hasAccessibilityPermission(prompt: false)
    }

    func refreshSecureInput() {
        let now = AppContext.isSecureInputActive()
        if now != secureInputActive { secureInputActive = now }
    }

    func requestAXPermission() {
        _ = AppContext.hasAccessibilityPermission(prompt: true)
    }

    func startEventTap() {
        guard axGranted, tap == nil, let coord = coordinator else { return }
        let t = EventTap { event, type in coord.handle(event: event, type: type) }
        t.onTapDisabled = { [weak coord] in coord?.resetBuffer() }
        do {
            try t.start()
            self.tap = t
        } catch {
            NSLog("[KeyFlow] EventTap failed: \(error)")
        }
    }

    func stopEventTap() {
        tap?.stop()
        tap = nil
    }

    private func rewireHotkey() {
        hotkey?.unregister()
        guard settings.tapModifier == nil, let kc = settings.hotkeyKeyCode else { return }
        let manager = HotkeyManager()
        _ = manager.register(keyCode: kc, modifiers: settings.hotkeyModifiers) { [weak self] in
            self?.coordinator?.convertLastWordManually()
        }
        self.hotkey = manager
    }

    func installHotkey() {
        rewireHotkey()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    var menuBar: MenuBarController?
    var settingsWindow: SettingsWindowController?
    private var axTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(state.settings.showInDock ? .regular : .accessory)
        state.refreshSecureInput()

        let dicts = loadBundledDicts()
        let detector = LayoutDetector(
            dicts: dicts,
            minLength: state.settings.minWordLength,
            exceptions: state.exceptions
        )
        state.coordinator = Coordinator(
            detector: detector,
            exceptions: state.exceptions,
            settings: state.settings
        )

        state.settings.launchAtLogin = LaunchAtLogin.isEnabled
        state.settings.save()

        menuBar = MenuBarController(state: state, openSettings: { [weak self] in self?.openSettings() })

        if state.axGranted {
            state.startEventTap()
            state.installHotkey()
        } else {
            openSettings()
        }

        axTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let was = self.state.axGranted
            self.state.refreshAXStatus()
            if !was && self.state.axGranted {
                self.state.startEventTap()
                self.state.installHotkey()
            }
            if was && !self.state.axGranted {
                self.state.stopEventTap()
            }
            // Re-arm the tap if the system disabled it while no event came
            // through to trigger the inline re-enable.
            if self.state.axGranted {
                self.state.tap?.rearmIfNeeded()
            }
            // Secure Keyboard Entry hides typing from our tap — surface it.
            self.state.refreshSecureInput()
        }
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(state: state)
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Clicking the Dock icon while no window is visible should open Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openSettings() }
        return true
    }

    private func loadBundledDicts() -> [Layout: WordDictionary] {
        var dicts: [Layout: WordDictionary] = [:]
        let resources = Bundle.main.resourceURL
        let devFallback = URL(fileURLWithPath: "Sources/KeyboardSwitcher/Resources")

        func tryLoad(_ name: String) -> WordDictionary? {
            for base in [resources, devFallback].compactMap({ $0 }) {
                let url = base.appendingPathComponent("\(name).txt")
                if FileManager.default.fileExists(atPath: url.path),
                   let dict = try? SetDictionary(contentsOf: url) {
                    return dict
                }
            }
            return SetDictionary(words: [])
        }

        dicts[.en] = tryLoad("en")
        dicts[.ru] = tryLoad("ru")
        dicts[.ua] = tryLoad("ua")
        return dicts
    }
}
