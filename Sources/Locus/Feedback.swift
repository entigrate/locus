import AppKit

enum Feedback {
    private static var activeFlashWindow: NSWindow?

    static func captureSuccess(windowBounds: CGRect) {
        playSound()
        // windowBounds is in CG coordinates (top-left origin), convert to AppKit
        guard let primaryScreen = NSScreen.screens.first else { return }
        let flippedY = primaryScreen.frame.height - windowBounds.origin.y - windowBounds.height
        let appKitRect = NSRect(
            x: windowBounds.origin.x,
            y: flippedY,
            width: windowBounds.width,
            height: windowBounds.height
        )
        flashWindow(at: appKitRect)
    }

    static func fullScreenCaptureSuccess() {
        playSound()
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.screens.first
        guard let screen else { return }
        // screen.frame is already in AppKit coordinates
        flashWindow(at: screen.frame)
    }

    static func captureFailure() {
        let store = SettingsStore.shared
        guard store.soundEnabled, let sound = NSSound(named: "Basso") else { return }
        sound.volume = store.soundVolume
        sound.play()
    }

    static func playSuccessSound() {
        playSound()
    }

    private static func playSound() {
        let store = SettingsStore.shared
        guard store.soundEnabled, let sound = NSSound(named: NSSound.Name(store.soundName)) else { return }
        sound.volume = store.soundVolume
        sound.play()
    }

    private static func flashWindow(at frame: NSRect) {
        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = NSColor.white.withAlphaComponent(0.3)
        window.level = .statusBar
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.alphaValue = 1
        window.orderFront(nil)

        // Hold a strong reference so ARC doesn't release it during the animation
        activeFlashWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                window.animator().alphaValue = 0
            } completionHandler: {
                window.orderOut(nil)
                activeFlashWindow = nil
            }
        }
    }
}
