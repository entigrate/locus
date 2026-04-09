import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum GIFExporter {
    enum Quality: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var fps: Int {
            switch self {
            case .small: 10
            case .medium: 15
            case .large: 24
            }
        }

        var scale: CGFloat {
            switch self {
            case .small: 0.5
            case .medium: 0.75
            case .large: 1.0
            }
        }

        /// Duration (seconds) below which full FPS is used
        fileprivate var fullFPSThreshold: Double {
            switch self {
            case .small: 4
            case .medium: 6
            case .large: 8
            }
        }

        /// Hard cap on total frames to bound file size
        fileprivate var maxFrames: Int {
            switch self {
            case .small: 100
            case .medium: 200
            case .large: 400
            }
        }
    }

    enum ExportError: Error {
        case noVideoTrack
        case gifCreationFailed
        case gifFinalizationFailed
    }

    static func adaptiveFrameParams(duration: Double, quality: Quality) -> (frameCount: Int, frameDelay: Double) {
        let baseFPS = Double(quality.fps)
        let effectiveFPS: Double = if duration <= quality.fullFPSThreshold {
            baseFPS
        } else {
            baseFPS / (1.0 + log2(duration / quality.fullFPSThreshold))
        }
        let frameCount = min(max(1, Int(effectiveFPS * duration)), quality.maxFrames)
        let frameDelay = duration / Double(frameCount)
        return (frameCount, frameDelay)
    }

    static func exportGIF(from videoURL: URL, quality: Quality) async throws -> Data {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw ExportError.noVideoTrack }
        let naturalSize = try await track.load(.naturalSize)

        return try await Task.detached {
            try Self.generateGIF(asset: asset, duration: duration, naturalSize: naturalSize, quality: quality)
        }.value
    }

    private static func generateGIF(asset: AVAsset, duration: CMTime, naturalSize: CGSize, quality: Quality) throws -> Data {
        let targetSize = CGSize(
            width: round(naturalSize.width * quality.scale),
            height: round(naturalSize.height * quality.scale)
        )

        let totalSeconds = CMTimeGetSeconds(duration)
        let (frameCount, frameInterval) = adaptiveFrameParams(duration: totalSeconds, quality: quality)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = CMTime(seconds: frameInterval / 2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: frameInterval / 2, preferredTimescale: 600)
        generator.maximumSize = targetSize
        generator.appliesPreferredTrackTransform = true

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw ExportError.gifCreationFailed
        }

        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0,
            ],
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        for frameIndex in 0 ..< frameCount {
            let time = CMTime(seconds: Double(frameIndex) * frameInterval, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: time, actualTime: nil)

            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: frameInterval,
                ],
            ]
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.gifFinalizationFailed
        }

        return data as Data
    }
}
