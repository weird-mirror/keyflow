import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(state: AppState) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        window.title = version.map { "KeyFlow \($0)" } ?? "KeyFlow"
        window.center()
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: SettingsView(state: state))
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }
}

private struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var newBlacklistID: String = ""
    @State private var newExceptionWord: String = ""
    @State private var exceptionsBump: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                axStatus
                if state.secureInputActive {
                    Divider()
                    secureInputWarning
                }
                Divider()
                enabledSection
                Divider()
                layoutsSection
                Divider()
                hotkeySection
                Divider()
                blacklistSection
                Divider()
                launchSection
                Divider()
                exceptionsSection
                Divider()
                supportSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Support KeyFlow").font(.headline)
            Text("KeyFlow is free and open-source. No cloud, no telemetry. If it saves you time, you can buy the developer a coffee.")
                .font(.caption).foregroundColor(.secondary)
            HStack(spacing: 10) {
                Button("Buy me a coffee ♥") { NSWorkspace.shared.open(Links.donate) }
                Button("View source") { NSWorkspace.shared.open(Links.repo) }
            }
        }
    }

    @ViewBuilder
    private var axStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accessibility").font(.headline)
            HStack {
                Image(systemName: state.axGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(state.axGranted ? .green : .orange)
                Text(state.axGranted
                     ? "Permission granted — keystrokes are being processed."
                     : "Required to read and correct keystrokes.")
                Spacer()
                if !state.axGranted {
                    Button("Open System Settings") {
                        state.requestAXPermission()
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private var secureInputWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                    .foregroundColor(.orange)
                Text("Secure Keyboard Entry is active").font(.headline)
            }
            Text("Some app is using macOS Secure Keyboard Entry, which hides your typing from KeyFlow (and every other layout switcher). KeyFlow can't correct anything until it's turned off.")
                .font(.caption).foregroundColor(.secondary)
            Text("Most often this is Terminal or iTerm: open that app's menu and uncheck “Secure Keyboard Entry”. A password field in a browser can also enable it temporarily.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
    }

    private var enabledSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Autocorrect on space / punctuation", isOn: Binding(
                get: { state.settings.enabled },
                set: { state.settings.enabled = $0; state.persist() }
            ))
            .font(.headline)

            Toggle("Live correction (after \(state.settings.liveAutoCorrectMinLength) characters)", isOn: Binding(
                get: { state.settings.liveAutoCorrect },
                set: { state.settings.liveAutoCorrect = $0; state.persist() }
            ))
            .font(.headline)
            Text("Switches layout mid-word as soon as it's clear you're typing in the wrong one — no need to wait for space.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var layoutsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active layouts").font(.headline)
            ForEach(Layout.allCases, id: \.self) { layout in
                Toggle(label(for: layout), isOn: Binding(
                    get: { state.settings.enabledLayouts.contains(layout) },
                    set: { state.setLayout(layout, enabled: $0) }
                ))
            }
            Text("Cmd-tap cycles through the enabled layouts only.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private func label(for layout: Layout) -> String {
        switch layout {
        case .en: return "English"
        case .ru: return "Русский"
        case .ua: return "Українська"
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Manual conversion hotkey").font(.headline)
            Picker("Trigger", selection: Binding(
                get: { state.settings.tapModifier ?? "none" },
                set: { newValue in
                    state.setTapModifier(newValue == "none" ? nil : newValue)
                }
            )) {
                Text("None").tag("none")
                Text("Tap ⌘ Cmd").tag("cmd")
                Text("Tap ⌥ Opt").tag("opt")
                Text("Tap ⌃ Ctrl").tag("ctrl")
                Text("Tap ⇧ Shift").tag("shift")
            }
            .pickerStyle(.menu)
            Text("Tap the modifier alone (no other key) within 0.5s to cycle the last word's layout.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var blacklistSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Blacklist").font(.headline)
            Text("Autocorrect is enabled everywhere except apps listed here.")
                .font(.caption).foregroundColor(.secondary)

            if state.settings.disabledBundleIDs.isEmpty {
                Text("No apps blacklisted.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                List(state.settings.disabledBundleIDs.sorted(), id: \.self) { id in
                    HStack {
                        Text(id).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            var s = state.settings.disabledBundleIDs
                            s.remove(id)
                            state.setBlacklist(s)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(minHeight: 80, maxHeight: 160)
            }

            HStack {
                TextField("Bundle ID (e.g. com.apple.Terminal)", text: $newBlacklistID)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let id = newBlacklistID.trimmingCharacters(in: .whitespaces)
                    guard !id.isEmpty else { return }
                    var s = state.settings.disabledBundleIDs
                    s.insert(id)
                    state.setBlacklist(s)
                    newBlacklistID = ""
                }
                .disabled(newBlacklistID.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Menu("Add from running apps…") {
                ForEach(runningAppList(), id: \.bundleID) { app in
                    Button("\(app.name)   \(app.bundleID)") {
                        var s = state.settings.disabledBundleIDs
                        s.insert(app.bundleID)
                        state.setBlacklist(s)
                    }
                }
            }
        }
    }

    private struct RunningAppRow {
        let name: String
        let bundleID: String
    }

    private func runningAppList() -> [RunningAppRow] {
        NSWorkspace.shared.runningApplications
            .compactMap { app -> RunningAppRow? in
                guard let id = app.bundleIdentifier, app.activationPolicy == .regular else { return nil }
                return RunningAppRow(name: app.localizedName ?? id, bundleID: id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at login", isOn: Binding(
                get: { state.settings.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            .font(.headline)

            Toggle("Show in Dock", isOn: Binding(
                get: { state.settings.showInDock },
                set: { state.setShowInDock($0) }
            ))
            .font(.headline)
        }
    }

    private var exceptionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exceptions").font(.headline)
            Text("Words the switcher will leave alone — neither auto-correct nor flag them.")
                .font(.caption).foregroundColor(.secondary)

            let all = state.exceptions.all()

            if all.isEmpty {
                Text("No exceptions.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                List(all, id: \.self) { word in
                    HStack {
                        Text(word).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            state.exceptions.remove(word)
                            exceptionsBump += 1
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(minHeight: 80, maxHeight: 160)
            }

            HStack {
                TextField("Word to exempt", text: $newExceptionWord)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let w = newExceptionWord.trimmingCharacters(in: .whitespaces)
                    guard !w.isEmpty else { return }
                    state.exceptions.add(w)
                    newExceptionWord = ""
                    exceptionsBump += 1
                }
                .disabled(newExceptionWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Spacer()
                Button("Clear all") {
                    state.clearExceptions()
                    exceptionsBump += 1
                }
                .disabled(all.isEmpty)
            }
        }
        .id(exceptionsBump)
    }
}
