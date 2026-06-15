import AppKit
import ApplicationServices

enum AppContext {
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
