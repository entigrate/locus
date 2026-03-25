import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()

    private let hotkeyCode: CGKeyCode = 5 // G key
    private let hotkeyModifiers: CGEventFlags = [.maskCommand, .maskShift]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotkey: (() -> Void)?

    private init() {}

    func register() {
        guard eventTap == nil else { return }
        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, _, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleEvent(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            #if DEBUG
                print("[Glimpse] Failed to create event tap — Accessibility permission may be missing")
            #endif
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        #if DEBUG
            print("[Glimpse] Event tap registered")
        #endif
    }

    func unregister() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

        if keyCode == hotkeyCode, flags == hotkeyModifiers {
            DispatchQueue.main.async { [self] in
                onHotkey?()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
