import Carbon
import Foundation

enum LayoutSource {
    static let enUS = "com.apple.keylayout.US"
    static let enABC = "com.apple.keylayout.ABC"
    static let ruPC = "com.apple.keylayout.RussianWin"
    static let ruApple = "com.apple.keylayout.Russian"
    static let uaPC = "com.apple.keylayout.Ukrainian-PC"
    static let uaApple = "com.apple.keylayout.Ukrainian"
}

struct LayoutSwitcher {
    static func currentSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    static func currentLayout() -> Layout? {
        guard let id = currentSourceID() else { return nil }
        if id.contains("Ukrainian") { return .ua }
        if id.contains("Russian") { return .ru }
        if id.contains("US") || id.contains("ABC") || id.contains("English") { return .en }
        return nil
    }

    @discardableResult
    static func select(sourceID: String) -> Bool {
        guard let cfList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else { return false }
        let list = cfList as! [TISInputSource]
        for source in list {
            guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            if id == sourceID {
                TISSelectInputSource(source)
                return true
            }
        }
        return false
    }

    @discardableResult
    static func selectLayout(_ layout: Layout) -> Bool {
        let candidates: [String]
        switch layout {
        case .en: candidates = [LayoutSource.enUS, LayoutSource.enABC]
        case .ru: candidates = [LayoutSource.ruPC, LayoutSource.ruApple]
        case .ua: candidates = [LayoutSource.uaPC, LayoutSource.uaApple]
        }
        for id in candidates {
            if select(sourceID: id) { return true }
        }
        return false
    }
}
