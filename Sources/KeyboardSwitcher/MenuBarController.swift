import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let state: AppState
    private let openSettings: () -> Void
    private let statusItem: NSStatusItem
    private let menu: NSMenu

    init(state: AppState, openSettings: @escaping () -> Void) {
        self.state = state
        self.openSettings = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()
        super.init()

        if let button = statusItem.button {
            button.title = "⌥"
            button.toolTip = "KeyFlow"
        }
        menu.delegate = self
        statusItem.menu = menu
        populate(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(
            title: state.settings.enabled ? "Pause autocorrect" : "Resume autocorrect",
            action: #selector(toggleEnabled), keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        let axItem = NSMenuItem(
            title: state.axGranted ? "✓ Accessibility granted" : "⚠︎ Accessibility required",
            action: nil, keyEquivalent: ""
        )
        axItem.isEnabled = false
        menu.addItem(axItem)

        if state.secureInputActive {
            let warn = NSMenuItem(
                title: "⚠︎ Secure Keyboard Entry is blocking input",
                action: #selector(showSettings), keyEquivalent: ""
            )
            warn.target = self
            menu.addItem(warn)
        }

        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let support = NSMenuItem(title: "Support KeyFlow ♥", action: #selector(openDonate), keyEquivalent: "")
        support.target = self
        menu.addItem(support)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func toggleEnabled() {
        state.settings.enabled.toggle()
        state.persist()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func openDonate() {
        NSWorkspace.shared.open(Links.donate)
    }
}
