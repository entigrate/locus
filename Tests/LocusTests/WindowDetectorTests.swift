@testable import Locus
import XCTest

final class WindowDetectorTests: XCTestCase {
    func testWindowUnderCursorDoesNotCrash() {
        // Smoke test: verify the function doesn't crash regardless of cursor position
        _ = WindowDetector.windowUnderCursor()
    }

    func testDetectedWindowProperties() {
        // If a window is found, verify all required fields are populated
        guard let window = WindowDetector.windowUnderCursor() else { return }
        XCTAssertFalse(window.ownerName.isEmpty)
        XCTAssertGreaterThan(window.bounds.width, 0)
        XCTAssertGreaterThan(window.bounds.height, 0)
    }
}
