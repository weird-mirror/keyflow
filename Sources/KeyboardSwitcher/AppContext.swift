import AppKit
import ApplicationServices
import Carbon

enum AppContext {
    // True when Secure Keyboard Entry is active anywhere in the session. While
    // it's on, macOS withholds keyDown events from ALL event taps (ours
    // included), so KeyFlow silently can't see typing. The usual culprit is
    // Terminal or iTerm with "Secure Keyboard Entry" enabled in their menu.
    static func isSecureInputActive() -> Bool {
        return IsSecureEventInputEnabled()
    }

    static func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func frontmostAppName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    static func isFocusedFieldSecure() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success, let element = focused else { return false }
        let axElement = element as! AXUIElement

        var role: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role)
        if let roleStr = role as? String, roleStr == "AXSecureTextField" { return true }

        var subrole: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXSubroleAttribute as CFString, &subrole)
        if let subStr = subrole as? String, subStr == "AXSecureTextField" { return true }

        return false
    }

    static func hasAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options)
    }
}
