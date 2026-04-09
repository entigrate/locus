import AppKit
import ScreenCaptureKit

enum ScreenCapture {
    static func captureWindowImage(windowID: CGWindowID, content: SCShareableContent? = nil) async -> CGImage? {
        do {
            let content = if let content { content } else { try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) }
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let scaleFactor = await MainActor.run {
                scaleFactorForPoint(CGPoint(x: scWindow.frame.midX, y: scWindow.frame.midY))
            }
            config.width = Int(scWindow.frame.width * scaleFactor)
            config.height = Int(scWindow.frame.height * scaleFactor)
            // Transparent background so we can detect overlay windows (e.g. screen-sharing borders)
            config.backgroundColor = .clear

            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
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

            let (mouseLocation, scaleFactor) = await MainActor.run {
                let point = NSEvent.mouseLocation
                return (point, scaleFactorForPoint(point))
            }
            let display = content.displays.first { $0.frame.contains(mouseLocation) } ?? content.displays.first
            guard let display else { return nil }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
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

    static func pngData(from image: CGImage) -> Data? {
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .png, properties: [:])
    }

    @MainActor
    static func copyToClipboard(_ pngData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
    }

    /// Check if an image is mostly transparent (e.g. a screen-sharing overlay border).
    static func isMostlyTransparent(_ image: CGImage) -> Bool {
        // If the image has no alpha channel, it can't be transparent
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            break
        }

        let sampleSize = 20
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        let totalPixels = sampleSize * sampleSize
        // Alpha is at byte offset 3 (RGBA premultiplied-last).
        // Threshold of 25 treats pixels with <10% opacity as transparent,
        // accounting for anti-aliased borders after downsampling.
        let transparentCount = stride(from: 3, to: totalPixels * 4, by: 4)
            .count { pixelData[$0] < 25 }

        return Double(transparentCount) / Double(totalPixels) > 0.75
    }

    @MainActor
    private static func scaleFactorForPoint(_ point: NSPoint) -> CGFloat {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.screens.first
        return screen?.backingScaleFactor ?? 2.0
    }

    private static func captureAndCopy(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> Data? {
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let pngData = pngData(from: image) else { return nil }
        await MainActor.run { copyToClipboard(pngData) }
        return pngData
    }
}
