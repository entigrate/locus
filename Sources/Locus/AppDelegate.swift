import AppKit
import ScreenCaptureKit
import SwiftUI

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
        HotkeyManager.shared.onOpenHistory = {
            Self.openHistoryWindow()
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

    // MARK: - Main Window

    private static var mainWindow: NSWindow?
    private static let mainWindowDelegate = MainWindowCloseHandler()

    static func openMainWindow(tab: MainTab) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let existing = mainWindow {
            if WindowState.shared.selectedTab != tab {
                WindowState.shared.selectedTab = tab
            }
            existing.makeKeyAndOrderFront(nil)
            return
        }
        WindowState.shared.selectedTab = tab
        let controller = NSHostingController(rootView: MainWindowView())
        let window = NSWindow(contentViewController: controller)
        window.title = "Locus"
        window.setContentSize(NSSize(width: 900, height: 600))
        window.minSize = NSSize(width: 600, height: 400)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setFrameAutosaveName("MainWindow")
        window.delegate = mainWindowDelegate
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    static func openHistoryWindow() {
        openMainWindow(tab: .history)
    }

    private class MainWindowCloseHandler: NSObject, NSWindowDelegate {
        func windowWillClose(_: Notification) {
            AppDelegate.mainWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Capture Actions

    static func performWindowCapture() {
        // Run window detection off the main thread to avoid blocking the event tap
        Task.detached {
            guard let window = WindowDetector.windowUnderCursor() else {
                #if DEBUG
                    print("[Locus] No window found under cursor")
                #endif
                await MainActor.run { Feedback.captureFailure() }
                return
            }

            #if DEBUG
                print("[Locus] Capturing: \(window.ownerName) (ID: \(window.windowID))")
            #endif

            if let pngData = await ScreenCapture.captureWindowToClipboard(windowID: window.windowID) {
                await MainActor.run {
                    Feedback.captureSuccess(windowBounds: window.bounds)
                    HistoryStore.shared.save(pngData: pngData, appName: window.ownerName, windowTitle: window.windowName)
                }
            } else {
                #if DEBUG
                    print("[Locus] Window capture failed")
                #endif
                await MainActor.run { Feedback.captureFailure() }
            }
        }
    }

    static func performFullScreenCapture() {
        Task.detached {
            #if DEBUG
                print("[Locus] Capturing full screen")
            #endif

            if let pngData = await ScreenCapture.captureFullScreenToClipboard() {
                await MainActor.run {
                    Feedback.fullScreenCaptureSuccess()
                    HistoryStore.shared.save(pngData: pngData, appName: nil, windowTitle: "Full Screen")
                }
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
