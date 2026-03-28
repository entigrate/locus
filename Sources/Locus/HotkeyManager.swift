import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private let tapRunLoopReady = DispatchSemaphore(value: 0)

    var onCaptureWindow: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?
    var onOpenHistory: (() -> Void)?
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

        // Run the event tap on a dedicated thread so main thread work
        // never blocks keystroke processing
        let thread = Thread { [weak self] in
            guard let self, let source = runLoopSource else { return }
            guard let runLoop = CFRunLoopGetCurrent() else { return }
            tapRunLoop = runLoop
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            // Schedule health check on this thread's run loop
            let timer = Timer(timeInterval: 5.0, repeats: true) { _ in
                if !CGEvent.tapIsEnabled(tap: tap) {
                    #if DEBUG
                        print("[Locus] Event tap was disabled by system — re-enabling")
                    #endif
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            RunLoop.current.add(timer, forMode: .common)

            tapRunLoopReady.signal()
            CFRunLoopRun()
        }
        thread.name = "com.locus.event-tap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
        tapRunLoopReady.wait()

        #if DEBUG
            print("[Locus] Event tap registered on dedicated thread")
        #endif
    }

    func unregister() {
        if let runLoop = tapRunLoop, let source = runLoopSource {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopStop(runLoop)
            runLoopSource = nil
            tapRunLoop = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        tapThread = nil
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

        return Unmanaged.passUnretained(event)
    }
}
