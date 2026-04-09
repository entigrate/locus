import AppKit

struct DetectedWindow {
    let windowID: CGWindowID
    let bounds: CGRect
    let ownerName: String
    let windowName: String?
    let alpha: Double
}

enum WindowDetector {
    /// Returns all candidate windows under the cursor, in front-to-back z-order.
    static func windowsUnderCursor() -> [DetectedWindow] {
        let mouseLocation = NSEvent.mouseLocation
        guard let primaryScreen = NSScreen.screens.first else { return [] }

        // Convert from AppKit coordinates (bottom-left origin) to CG coordinates (top-left origin)
        let cgPoint = CGPoint(
            x: mouseLocation.x,
            y: primaryScreen.frame.height - mouseLocation.y
        )

        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var results = [DetectedWindow]()

        // Windows are returned in front-to-back z-order
        for windowInfo in windowInfoList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int
            else { continue }

            // Skip non-normal windows (menu bar, dock, overlays)
            if layer != 0 { continue }

            // Never capture ourselves
            if ownerName == ProcessInfo.processInfo.processName { continue }

            let alpha = windowInfo[kCGWindowAlpha as String] as? Double ?? 1.0

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // Skip tiny windows (likely invisible or decorative)
            if bounds.width < 50 || bounds.height < 50 { continue }

            if bounds.contains(cgPoint) {
                let windowName = windowInfo[kCGWindowName as String] as? String
                results.append(DetectedWindow(
                    windowID: windowID,
                    bounds: bounds,
                    ownerName: ownerName,
                    windowName: windowName,
                    alpha: alpha
                ))
            }
        }

        // Prefer fully opaque windows over semi-transparent ones (likely overlays),
        // but keep both as candidates. Stable sort preserves z-order within each group.
        return results.sorted { $0.alpha > $1.alpha }
    }

    static func windowUnderCursor() -> DetectedWindow? {
        windowsUnderCursor().first
    }
}
