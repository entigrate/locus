import AppKit
import ScreenCaptureKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var accessibilityTimer: Timer?

    private(set) var hotkeyReady = false {
        didSet { NotificationCenter.default.post(name: .locusStatusChanged, object: nil) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestScreenRecording()
        setupHotkey()
    }

    private func requestScreenRecording() {
        if #available(macOS 15.0, *) {
            if CGPreflightScreenCaptureAccess() { return }
            CGRequestScreenCaptureAccess()
        } else {
            // macOS 14: no pre-request API, trigger prompt by touching ScreenCaptureKit once
            Task {
                _ = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            }
        }
    }

    // MARK: - Accessibility Permission

    private func setupHotkey() {
        HotkeyManager.shared.onCaptureWindow = {
            Self.performWindowCapture()
        }
        HotkeyManager.shared.onCaptureFullScreen = {
            Self.performFullScreenCapture()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            #if DEBUG
                print("[Locus] Accessibility permission: true")
            #endif
            HotkeyManager.shared.register()
            hotkeyReady = true
        } else {
            #if DEBUG
                print("[Locus] Accessibility permission: false — polling until granted...")
            #endif
            startAccessibilityPolling()
        }
    }

    private func startAccessibilityPolling() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                #if DEBUG
                    print("[Locus] Accessibility permission granted!")
                #endif
                timer.invalidate()
                self?.accessibilityTimer = nil
                HotkeyManager.shared.register()
                self?.hotkeyReady = true
            }
        }
    }

    // MARK: - Capture Actions

    static func performWindowCapture() {
        guard let window = WindowDetector.windowUnderCursor() else {
            #if DEBUG
                print("[Locus] No window found under cursor")
            #endif
            Feedback.captureFailure()
            return
        }

        #if DEBUG
            print("[Locus] Capturing: \(window.ownerName) (ID: \(window.windowID))")
        #endif

        Task {
            if await ScreenCapture.captureWindowToClipboard(windowID: window.windowID) {
                await MainActor.run { Feedback.captureSuccess(windowBounds: window.bounds) }
            } else {
                #if DEBUG
                    print("[Locus] Window capture failed")
                #endif
                await MainActor.run { Feedback.captureFailure() }
            }
        }
    }

    static func performFullScreenCapture() {
        #if DEBUG
            print("[Locus] Capturing full screen")
        #endif

        Task {
            if await ScreenCapture.captureFullScreenToClipboard() {
                await MainActor.run { Feedback.fullScreenCaptureSuccess() }
            } else {
                #if DEBUG
                    print("[Locus] Full screen capture failed")
                #endif
                await MainActor.run { Feedback.captureFailure() }
            }
        }
    }
}

extension Notification.Name {
    static let locusStatusChanged = Notification.Name("locusStatusChanged")
}
