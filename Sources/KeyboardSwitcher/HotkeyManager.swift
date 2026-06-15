import Carbon
import Foundation

final class HotkeyManager {
    typealias Action = () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: Action?
    private static var sharedInstance: HotkeyManager?

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping Action) -> Bool {
        unregister()
        self.action = action
        HotkeyManager.sharedInstance = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            HotkeyManager.sharedInstance?.action?()
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B425357), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let h = handlerRef { RemoveEventHandler(h) }
        hotKeyRef = nil
        handlerRef = nil
    }

    deinit { unregister() }
}
