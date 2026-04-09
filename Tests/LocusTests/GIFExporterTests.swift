@testable import Locus
import XCTest

final class GIFExporterTests: XCTestCase {
    // MARK: - Short videos use full FPS

    func testShortVideoUsesFullFPSSmall() {
        let (count, _) = GIFExporter.adaptiveFrameParams(duration: 2, quality: .small)
        // 2s * 10fps = 20 frames
        XCTAssertEqual(count, 20)
    }

    func testShortVideoUsesFullFPSMedium() {
        let (count, _) = GIFExporter.adaptiveFrameParams(duration: 5, quality: .medium)
        // 5s * 15fps = 75 frames
        XCTAssertEqual(count, 75)
    }

    func testShortVideoUsesFullFPSLarge() {
        let (count, _) = GIFExporter.adaptiveFrameParams(duration: 8, quality: .large)
        // 8s * 24fps = 192 frames
        XCTAssertEqual(count, 192)
    }

    // MARK: - Logarithmic decay past threshold

    func testLongerVideoReducesFrames() {
        let (shortCount, _) = GIFExporter.adaptiveFrameParams(duration: 6, quality: .medium)
        let (longCount, _) = GIFExporter.adaptiveFrameParams(duration: 30, quality: .medium)
        // 30s should have far fewer frames than 5x the 6s count
        XCTAssertLessThan(longCount, shortCount * 5)
    }

    func testFrameCountGrowsSublinearly() {
        let (count10, _) = GIFExporter.adaptiveFrameParams(duration: 10, quality: .medium)
        let (count20, _) = GIFExporter.adaptiveFrameParams(duration: 20, quality: .medium)
        let (count60, _) = GIFExporter.adaptiveFrameParams(duration: 60, quality: .medium)
        // Doubling duration should not double frame count past threshold
        XCTAssertLessThan(count20, count10 * 2)
        XCTAssertLessThan(count60, count20 * 3)
    }

    // MARK: - Hard cap

    func testMaxFramesCapSmall() {
        let (count, _) = GIFExporter.adaptiveFrameParams(duration: 300, quality: .small)
        XCTAssertLessThanOrEqual(count, 100)
    }

    func testMaxFramesCapMedium() {
        let (count, _) = GIFExporter.adaptiveFrameParams(duration: 300, quality: .medium)
        XCTAssertLessThanOrEqual(count, 200)
    }

    func testMaxFramesCapLarge() {
        let (count, _) = GIFExporter.adaptiveFrameParams(duration: 300, quality: .large)
        XCTAssertLessThanOrEqual(count, 400)
    }

    // MARK: - Frame delay preserves total duration

    func testFrameDelayTimesCountEqualsDuration() {
        let durations: [Double] = [1, 5, 10, 30, 60, 120]
        for duration in durations {
            for quality in GIFExporter.Quality.allCases {
                let (count, delay) = GIFExporter.adaptiveFrameParams(duration: duration, quality: quality)
                let reconstructed = Double(count) * delay
                XCTAssertEqual(
                    reconstructed,
                    duration,
                    accuracy: 0.001,
                    "duration=\(duration) quality=\(quality.rawValue)"
                )
            }
        }
    }

    // MARK: - Edge cases

    func testVeryShortVideoReturnsAtLeastOneFrame() {
        let (count, _) = GIFExporter.adaptiveFrameParams(duration: 0.01, quality: .small)
        XCTAssertEqual(count, 1)
    }

    func testHigherQualityProducesMoreFrames() {
        let duration = 15.0
        let (small, _) = GIFExporter.adaptiveFrameParams(duration: duration, quality: .small)
        let (medium, _) = GIFExporter.adaptiveFrameParams(duration: duration, quality: .medium)
        let (large, _) = GIFExporter.adaptiveFrameParams(duration: duration, quality: .large)
        XCTAssertLessThan(small, medium)
        XCTAssertLessThan(medium, large)
    }
}
