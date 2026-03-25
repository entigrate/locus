import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var accessibilityTimer: Timer?
    private(set) var hotkeyReady = false {
        didSet { NotificationCenter.default.post(name: .glimpseStatusChanged, object: nil) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 15.0, *) {
            let has = CGPreflightScreenCaptureAccess()
            #if DEBUG
                print("[Glimpse] Screen Recording permission: \(has)")
            #endif
            if !has {
                CGRequestScreenCaptureAccess()
            }
        }

        setupHotkey()
    }

    private func setupHotkey() {
        HotkeyManager.shared.onHotkey = {
            Self.performCapture()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            #if DEBUG
                print("[Glimpse] Accessibility permission: true")
            #endif
            HotkeyManager.shared.register()
            hotkeyReady = true
        } else {
            #if DEBUG
                print("[Glimpse] Accessibility permission: false — polling until granted...")
            #endif
            startAccessibilityPolling()
        }
    }

    private func startAccessibilityPolling() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                #if DEBUG
                    print("[Glimpse] Accessibility permission granted!")
                #endif
                timer.invalidate()
                self?.accessibilityTimer = nil
                HotkeyManager.shared.register()
                self?.hotkeyReady = true
            }
        }
    }

    static func performCapture() {
        guard let window = WindowDetector.windowUnderCursor() else {
            #if DEBUG
                print("[Glimpse] No window found under cursor")
            #endif
            Feedback.captureFailure()
            return
        }

        #if DEBUG
            print("[Glimpse] Capturing: \(window.ownerName) (ID: \(window.windowID))")
        #endif

        Task {
            if await ScreenCapture.captureToClipboard(windowID: window.windowID) {
                await MainActor.run { Feedback.captureSuccess(windowBounds: window.bounds) }
            } else {
                #if DEBUG
                    print("[Glimpse] Capture failed")
                #endif
                await MainActor.run { Feedback.captureFailure() }
            }
        }
    }
}

extension Notification.Name {
    static let glimpseStatusChanged = Notification.Name("glimpseStatusChanged")
}
