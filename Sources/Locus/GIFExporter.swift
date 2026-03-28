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
    }

    enum ExportError: Error {
        case noVideoTrack
        case gifCreationFailed
        case gifFinalizationFailed
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

        let frameInterval = 1.0 / Double(quality.fps)
        let totalSeconds = CMTimeGetSeconds(duration)
        let frameCount = max(1, Int(totalSeconds * Double(quality.fps)))

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
