import CoreGraphics
import Foundation

final class Coordinator {
    private let buffer = WordBuffer()
    private let detector: LayoutDetector
    private let exceptions: ExceptionsStore
    private var settings: Settings
    private let focus = FocusContext()

    private struct CompletedWord {
        let text: String
        let boundary: String
        let layoutAtTime: Layout
    }

    private var lastCompletedWord: CompletedWord?

    private var modifierTapStart: Date?
    private var lastFlags: CGEventFlags = []

    init(detector: LayoutDetector, exceptions: ExceptionsStore, settings: Settings) {
        self.detector = detector
        self.exceptions = exceptions
        self.settings = settings
    }

    func update(settings: Settings) {
        self.settings = settings
    }

    // Called when the event tap was disabled and re-enabled by the system —
    // keystrokes were lost, so the buffer is unreliable and must be cleared.
    func resetBuffer() {
        buffer.reset()
        lastCompletedWord = nil
        modifierTapStart = nil
    }

    func handle(event: CGEvent, type: CGEventType) -> CGEvent? {
        if Replayer.isSynthetic(event) { return event }

        switch type {
        case .leftMouseDown, .rightMouseDown:
            buffer.reset()
            lastCompletedWord = nil
            modifierTapStart = nil
            focus.invalidateSecure() // a click can move focus into/out of a secure field
            return event
        case .flagsChanged:
            handleFlagsChanged(event)
            return event
        case .keyDown:
            modifierTapStart = nil
            return handleKeyDown(event)
        default:
            return event
        }
    }

    private static let allMods: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    private func maskFor(_ name: String) -> CGEventFlags? {
        switch name.lowercased() {
        case "cmd", "command": return .maskCommand
        case "ctrl", "control": return .maskControl
        case "opt", "alt", "option": return .maskAlternate
        case "shift": return .maskShift
        default: return nil
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        defer { lastFlags = event.flags }
        guard let modName = settings.tapModifier, let target = maskFor(modName) else { return }

        guard settings.appAllowed(focus.bundleID) else {
            modifierTapStart = nil
            return
        }

        let flags = event.flags
        let wasPressed = lastFlags.contains(target)
        let isPressed = flags.contains(target)

        if !wasPressed && isPressed {
            let onlyTarget = flags.intersection(Coordinator.allMods) == target
            modifierTapStart = onlyTarget ? Date() : nil
        } else if wasPressed && !isPressed {
            if let start = modifierTapStart,
               Date().timeIntervalSince(start) < settings.tapWindowSeconds {
                modifierTapStart = nil
                DispatchQueue.main.async { [weak self] in
                    self?.convertLastWordManually()
                }
            } else {
                modifierTapStart = nil
            }
        } else {
            modifierTapStart = nil
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> CGEvent? {
        guard settings.enabled else { return event }

        guard settings.appAllowed(focus.bundleID) else {
            buffer.reset()
            lastCompletedWord = nil
            return event
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Tab moves focus between fields — the next secure-field check must re-query.
        if keyCode == 48 { focus.invalidateSecure() }

        if settings.skipSecureFields && focus.isFocusedFieldSecure() {
            buffer.reset()
            lastCompletedWord = nil
            return event
        }

        let flags = event.flags
        let hasCmd = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasOpt = flags.contains(.maskAlternate)

        if hasCmd || hasCtrl || hasOpt {
            buffer.reset()
            return event
        }

        if keyCode == 51 { // Backspace
            buffer.backspace()
            return event
        }

        var len = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &chars)
        let s = String(utf16CodeUnits: chars, count: len)

        switch KeyClassifier.classify(unicodeString: s, hasModifier: false) {
        case .wordChar(let ch):
            buffer.append(ch)
            maybeTriggerLiveCorrection()
            return event
        case .boundary:
            return triggerDetect(event: event, boundaryString: s)
        case .ignored:
            return event
        }
    }

    private func maybeTriggerLiveCorrection() {
        guard settings.liveAutoCorrect,
              buffer.count >= settings.liveAutoCorrectMinLength,
              let activeLayout = LayoutSwitcher.currentLayout(),
              let result = detector.detectLivePrefix(
                buffer: buffer.current,
                activeLayout: activeLayout,
                enabledLayouts: settings.enabledLayouts,
                minLength: settings.liveAutoCorrectMinLength
              )
        else { return }
        let snapshot = buffer.current
        let target = result.target
        DispatchQueue.main.async { [weak self] in
            self?.applyLiveCorrection(snapshotPrefix: snapshot, target: target)
        }
    }

    // Runs on the main queue after a live trigger was scheduled. By the time
    // it fires the user may have typed more chars or hit a boundary, so we
    // re-read the buffer and act on the current state — not the snapshot.
    private func applyLiveCorrection(snapshotPrefix: String, target: Layout) {
        let current = buffer.current
        guard !current.isEmpty, current.hasPrefix(snapshotPrefix) else { return }
        guard let activeLayout = LayoutSwitcher.currentLayout(), activeLayout != target else { return }
        let translated = KeyTranslator.translate(current, from: activeLayout, to: target)
        guard translated != current else { return }

        Replayer.sendBackspaces(count: current.count)
        LayoutSwitcher.selectLayout(target)
        Replayer.typeString(translated)
        buffer.reset()
        for ch in translated { buffer.append(ch) }
    }

    private func triggerDetect(event: CGEvent, boundaryString: String) -> CGEvent? {
        let word = buffer.current
        buffer.reset()
        guard let layout = LayoutSwitcher.currentLayout() else { return event }
        if !word.isEmpty {
            lastCompletedWord = CompletedWord(text: word, boundary: boundaryString, layoutAtTime: layout)
        }
        guard settings.autoCorrectOnBoundary, !word.isEmpty else { return event }

        let result = detector.detect(word: word, activeLayout: layout)
        switch result {
        case .skip, .ambiguous:
            return event
        case .wrongLayout(let corrected, let target):
            guard settings.enabledLayouts.contains(target) else { return event }
            DispatchQueue.main.async { [weak self] in
                self?.performAutoCorrection(
                    original: word,
                    corrected: corrected,
                    target: target,
                    boundary: boundaryString
                )
            }
            return nil
        }
    }

    private func performAutoCorrection(original: String, corrected: String, target: Layout, boundary: String) {
        Replayer.sendBackspaces(count: original.count)
        LayoutSwitcher.selectLayout(target)
        Replayer.typeString(corrected)
        Replayer.typeString(boundary)
    }

    // Manual hotkey: cycle the keyboard layout to the next enabled one and
    // re-render the last word in that layout.
    func convertLastWordManually() {
        guard let layout = LayoutSwitcher.currentLayout() else { return }
        let target = layout.next(in: settings.enabledLayouts)
        guard target != layout else { return }

        if !buffer.isEmpty {
            let word = buffer.current
            let translated = KeyTranslator.translate(word, from: layout, to: target)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                Replayer.sendBackspaces(count: word.count)
                LayoutSwitcher.selectLayout(target)
                Replayer.typeString(translated)
                self.buffer.reset()
                for ch in translated { self.buffer.append(ch) }
            }
            return
        }

        if let last = lastCompletedWord {
            let translated = KeyTranslator.translate(last.text, from: last.layoutAtTime, to: target)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                Replayer.sendBackspaces(count: last.text.count + last.boundary.count)
                LayoutSwitcher.selectLayout(target)
                Replayer.typeString(translated)
                Replayer.typeString(last.boundary)
                self.lastCompletedWord = CompletedWord(text: translated, boundary: last.boundary, layoutAtTime: target)
            }
            return
        }

        // Nothing recent to convert — still cycle the keyboard so the tap is
        // never a no-op.
        DispatchQueue.main.async {
            LayoutSwitcher.selectLayout(target)
        }
    }
}
