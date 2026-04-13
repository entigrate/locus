import AVFoundation

enum VideoExporter {
    enum ExportError: Error {
        case exportFailed
    }

    static func exportMP4WithoutAudio(from sourceURL: URL) async throws -> URL {
        let asset = AVAsset(url: sourceURL)
        let composition = AVMutableComposition()

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let duration = try await asset.load(.duration)

        for track in videoTracks {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: track,
                at: .zero
            )
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("locus-export")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw ExportError.exportFailed
        }
        session.outputFileType = .mp4
        session.outputURL = outputURL

        await session.export()

        guard session.status == .completed else {
            throw session.error ?? ExportError.exportFailed
        }

        return outputURL
    }
}
