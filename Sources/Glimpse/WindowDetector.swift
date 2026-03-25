import AppKit

struct DetectedWindow {
    let windowID: CGWindowID
    let bounds: CGRect
    let ownerName: String
    let windowName: String?
}

enum WindowDetector {
    static func windowUnderCursor() -> DetectedWindow? {
        let mouseLocation = NSEvent.mouseLocation
        guard let primaryScreen = NSScreen.screens.first else { return nil }

        // Convert from AppKit coordinates (bottom-left origin) to CG coordinates (top-left origin)
        let cgPoint = CGPoint(
            x: mouseLocation.x,
            y: primaryScreen.frame.height - mouseLocation.y
        )

        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

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
                return DetectedWindow(
                    windowID: windowID,
                    bounds: bounds,
                    ownerName: ownerName,
                    windowName: windowName
                )
            }
        }

        return nil
    }
}
