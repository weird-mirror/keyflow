import AppKit
import ApplicationServices

// Caches the two pieces of context the event-tap hot path needs — the frontmost
// app's bundle ID and whether the focused field is secure — so we DON'T issue a
// cross-process NSWorkspace query and (worse) a synchronous Accessibility tree
// traversal on every single keystroke.
//
// Those synchronous calls were the cause of the intermittent "layout switches
// but the word isn't converted" bug: in busy apps the per-keystroke AX query
// could block long enough to trip macOS's event-tap watchdog, which disables
// the tap and drops keyDown events (so the word buffer stays empty) while
// flagsChanged still comes through after re-enable.
//
// All access happens on the main run loop (the tap fires there, and the
// workspace notification is delivered on .main), so no locking is required.
final class FocusContext {
    private(set) var bundleID: String?
    private var secureDirty = true
    private var cachedSecure = false
    private var activationObserver: NSObjectProtocol?

    init() {
        bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.bundleID = app?.bundleIdentifier
                ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            self?.secureDirty = true
        }
    }

    deinit {
        if let o = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
    }

    // Mark the secure-field state stale because focus may have moved — called on
    // mouse clicks and Tab presses. The next isFocusedFieldSecure() re-queries
    // once, then caches until focus can change again.
    func invalidateSecure() {
        secureDirty = true
    }

    func isFocusedFieldSecure() -> Bool {
        if secureDirty {
            cachedSecure = AppContext.isFocusedFieldSecure()
            secureDirty = false
        }
        return cachedSecure
    }
}
