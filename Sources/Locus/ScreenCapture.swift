import AppKit
import ScreenCaptureKit

enum ScreenCapture {
    static func captureWindowToClipboard(windowID: CGWindowID) async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let scaleFactor = await MainActor.run { NSScreen.screens.first?.backingScaleFactor ?? 2.0 }
            config.width = Int(scWindow.frame.width * scaleFactor)
            config.height = Int(scWindow.frame.height * scaleFactor)

            return try await captureAndCopy(filter: filter, configuration: config)
        } catch {
            #if DEBUG
                print("[Locus] Window capture error: \(error)")
            #endif
            return nil
        }
    }

    static func captureFullScreenToClipboard() async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return nil }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let scaleFactor = await MainActor.run { NSScreen.screens.first?.backingScaleFactor ?? 2.0 }
            config.width = Int(CGFloat(display.width) * scaleFactor)
            config.height = Int(CGFloat(display.height) * scaleFactor)

            return try await captureAndCopy(filter: filter, configuration: config)
        } catch {
            #if DEBUG
                print("[Locus] Full screen capture error: \(error)")
            #endif
            return nil
        }
    }

    private static func captureAndCopy(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> Data? {
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:])
        else { return nil }

        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(pngData, forType: .png)
        }
        return pngData
    }
}
