import AppKit
import ScreenCaptureKit

enum ScreenCapture {
    static func captureToClipboard(windowID: CGWindowID) async -> Bool {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return false
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let scaleFactor = await MainActor.run { NSScreen.screens.first?.backingScaleFactor ?? 2.0 }
            config.width = Int(scWindow.frame.width * scaleFactor)
            config.height = Int(scWindow.frame.height * scaleFactor)

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            guard let tiffData = nsImage.tiffRepresentation else { return false }

            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setData(tiffData, forType: .tiff)
            }
            return true
        } catch {
            #if DEBUG
                print("[Glimpse] Capture error: \(error)")
            #endif
            return false
        }
    }
}
