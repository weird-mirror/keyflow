import CoreGraphics
import Foundation

enum EventTapError: Error {
    case couldNotCreate
    case accessibilityDenied
}

final class EventTap {
    typealias Handler = (CGEvent, CGEventType) -> CGEvent?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: Handler

    // Called when the tap is disabled by the system (timeout / user input) and
    // re-enabled. Keystrokes were dropped while it was off, so the owner should
    // discard any partial word buffer to avoid acting on stale input.
    var onTapDisabled: (() -> Void)?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start() throws {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let t = me.tap { CGEvent.tapEnable(tap: t, enable: true) }
                    me.onTapDisabled?()
                    return Unmanaged.passUnretained(event)
                }
                if let out = me.handler(event, type) {
                    return Unmanaged.passUnretained(out)
                } else {
                    return nil
                }
            },
            userInfo: info
        ) else {
            throw EventTapError.couldNotCreate
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
    }

    // Re-enable the tap if the system disabled it while no event came through to
    // trigger the inline re-enable. Called periodically by the app watchdog so a
    // dropped tap never silently stays dead.
    func rearmIfNeeded() {
        guard let tap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            onTapDisabled?()
        }
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }
}
