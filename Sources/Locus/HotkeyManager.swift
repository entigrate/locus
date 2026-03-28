import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onCaptureWindow: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    var onRecordWindow: (() -> Void)?
    var onRecordFullScreen: (() -> Void)?
    var isRecordingShortcut = false

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
                print("[Locus] Failed to create event tap — Accessibility permission may be missing")
            #endif
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        #if DEBUG
            print("[Locus] Event tap registered")
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
        if isRecordingShortcut {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let store = SettingsStore.shared
        if store.captureWindow.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { [self] in onCaptureWindow?() }
            return nil
        }

        if store.captureFullScreen.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { [self] in onCaptureFullScreen?() }
            return nil
        }

        if store.openHistory.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { [self] in onOpenHistory?() }
            return nil
        }

        if store.recordWindow.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { [self] in onRecordWindow?() }
            return nil
        }

        if store.recordFullScreen.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { [self] in onRecordFullScreen?() }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
