@testable import Locus
import XCTest

final class ScreenCaptureTests: XCTestCase {
    // MARK: - isMostlyTransparent

    func testFullyOpaqueImageIsNotTransparent() {
        let image = createImage(width: 100, height: 100, transparentFraction: 0)
        XCTAssertFalse(ScreenCapture.isMostlyTransparent(image))
    }

    func testFullyTransparentImageIsTransparent() {
        let image = createImage(width: 100, height: 100, transparentFraction: 1.0)
        XCTAssertTrue(ScreenCapture.isMostlyTransparent(image))
    }

    func testHalfTransparentImageIsNotTransparent() {
        let image = createImage(width: 100, height: 100, transparentFraction: 0.5)
        XCTAssertFalse(ScreenCapture.isMostlyTransparent(image))
    }

    func testNinetyPercentTransparentImageIsTransparent() {
        let image = createImage(width: 100, height: 100, transparentFraction: 0.95)
        XCTAssertTrue(ScreenCapture.isMostlyTransparent(image))
    }

    func testBorderOnlyImageIsTransparent() {
        // Simulates a screen-sharing border: opaque 3px border, transparent interior
        // Uses realistic window dimensions so the border is negligible after downsampling
        let image = createBorderImage(width: 1000, height: 800, borderWidth: 3)
        XCTAssertTrue(ScreenCapture.isMostlyTransparent(image))
    }

    func testImageWithNoAlphaChannelIsNotTransparent() {
        let image = createOpaqueRGBImage(width: 100, height: 100)
        XCTAssertFalse(ScreenCapture.isMostlyTransparent(image))
    }

    func testSmallImageStillWorks() {
        let image = createImage(width: 10, height: 10, transparentFraction: 1.0)
        XCTAssertTrue(ScreenCapture.isMostlyTransparent(image))
    }

    // MARK: - Helpers

    /// Creates an RGBA image where `transparentFraction` of the pixels (from the top) are transparent.
    private func createImage(width: Int, height: Int, transparentFraction: Double) -> CGImage {
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let transparentRows = Int(Double(height) * transparentFraction)

        for row in 0 ..< height {
            for col in 0 ..< width {
                let offset = (row * width + col) * 4
                if row < transparentRows {
                    pixelData[offset] = 0
                    pixelData[offset + 1] = 0
                    pixelData[offset + 2] = 0
                    pixelData[offset + 3] = 0
                } else {
                    pixelData[offset] = 255
                    pixelData[offset + 1] = 0
                    pixelData[offset + 2] = 0
                    pixelData[offset + 3] = 255
                }
            }
        }

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            XCTFail("Failed to create test image")
            // Return a 1x1 fallback so tests can still report meaningful failures
            return createFallbackImage()
        }
        return image
    }

    /// Creates an image with an opaque border and transparent interior.
    private func createBorderImage(width: Int, height: Int, borderWidth: Int) -> CGImage {
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        for row in 0 ..< height {
            for col in 0 ..< width {
                let offset = (row * width + col) * 4
                let isBorder = row < borderWidth || row >= height - borderWidth ||
                    col < borderWidth || col >= width - borderWidth
                if isBorder {
                    pixelData[offset] = 255
                    pixelData[offset + 1] = 0
                    pixelData[offset + 2] = 0
                    pixelData[offset + 3] = 255
                }
            }
        }

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            XCTFail("Failed to create border test image")
            return createFallbackImage()
        }
        return image
    }

    /// Creates an opaque image with no usable alpha channel (noneSkipLast).
    private func createOpaqueRGBImage(width: Int, height: Int) -> CGImage {
        var pixelData = [UInt8](repeating: 255, count: width * height * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ), let image = context.makeImage() else {
            XCTFail("Failed to create opaque test image")
            return createFallbackImage()
        }
        return image
    }

    private func createFallbackImage() -> CGImage {
        var pixel: [UInt8] = [255, 0, 0, 255]
        let ctx = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return ctx?.makeImage() ?? CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ).unsafelyUnwrapped.makeImage().unsafelyUnwrapped
    }
}
