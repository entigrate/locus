import AppKit

enum Feedback {
    private static var activeFlashWindow: NSWindow?

    static func captureSuccess(windowBounds: CGRect) {
        NSSound(named: "Glass")?.play()
        flashWindow(at: windowBounds)
    }

    static func captureFailure() {
        NSSound(named: "Basso")?.play()
    }

    private static func flashWindow(at bounds: CGRect) {
        guard let primaryScreen = NSScreen.screens.first else { return }
        let flippedY = primaryScreen.frame.height - bounds.origin.y - bounds.height

        let flashRect = NSRect(
            x: bounds.origin.x,
            y: flippedY,
            width: bounds.width,
            height: bounds.height
        )

        let window = NSWindow(
            contentRect: flashRect,
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
