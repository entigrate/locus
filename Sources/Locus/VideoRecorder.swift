import AppKit
import AVFoundation
import ScreenCaptureKit

@MainActor
final class VideoRecorder: ObservableObject {
    static let shared = VideoRecorder()

    @Published private(set) var isRecording = false
    @Published private(set) var elapsedTime: TimeInterval = 0

    private var stream: SCStream?
    private var outputHandler: StreamOutputHandler?
    private var outputURL: URL?
    private var elapsedTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingAppName: String?
    private var recordingWindowTitle: String?

    var formattedElapsedTime: String {
        let total = Int(elapsedTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private init() {}

    // MARK: - Start Recording

    func startWindowRecording() async {
        guard !isRecording else { return }

        guard let window = WindowDetector.windowUnderCursor() else {
            Feedback.captureFailure()
            return
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard let scWindow = content.windows.first(where: { $0.windowID == window.windowID }) else {
                Feedback.captureFailure()
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let scaleFactor = scaleFactorForPoint(CGPoint(x: scWindow.frame.midX, y: scWindow.frame.midY))
            config.width = Int(scWindow.frame.width * scaleFactor)
            config.height = Int(scWindow.frame.height * scaleFactor)
            config.capturesAudio = true
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

            recordingAppName = window.ownerName
            recordingWindowTitle = window.windowName

            try await beginCapture(filter: filter, config: config)
        } catch {
            #if DEBUG
                print("[Locus] Window recording error: \(error)")
            #endif
            Feedback.captureFailure()
        }
    }

    func startFullScreenRecording() async {
        guard !isRecording else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mouseLocation = NSEvent.mouseLocation
            let scaleFactor = scaleFactorForPoint(mouseLocation)
            let display = content.displays.first { $0.frame.contains(mouseLocation) } ?? content.displays.first
            guard let display else {
                Feedback.captureFailure()
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(CGFloat(display.width) * scaleFactor)
            config.height = Int(CGFloat(display.height) * scaleFactor)
            config.capturesAudio = true
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

            recordingAppName = nil
            recordingWindowTitle = "Full Screen"

            try await beginCapture(filter: filter, config: config)
        } catch {
            #if DEBUG
                print("[Locus] Full screen recording error: \(error)")
            #endif
            Feedback.captureFailure()
        }
    }

    private func beginCapture(filter: SCContentFilter, config: SCStreamConfiguration) async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("locus-recording")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let url = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        outputURL = url

        let handler = try StreamOutputHandler(outputURL: url, width: config.width, height: config.height)
        outputHandler = handler

        let stream = SCStream(filter: filter, configuration: config, delegate: handler)
        try stream.addStreamOutput(handler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.locus.video", qos: .userInitiated))
        try stream.addStreamOutput(handler, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.locus.audio", qos: .userInitiated))

        try await stream.startCapture()
        self.stream = stream

        isRecording = true
        recordingStartTime = Date()
        elapsedTime = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = recordingStartTime else { return }
                elapsedTime = -start.timeIntervalSinceNow
            }
        }

        Feedback.playSuccessSound()
    }

    // MARK: - Stop Recording

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        elapsedTime = 0

        guard let stream, let outputHandler, let outputURL else { return }
        let appName = recordingAppName
        let windowTitle = recordingWindowTitle
        recordingStartTime = nil
        recordingAppName = nil
        recordingWindowTitle = nil

        Task {
            do {
                try await stream.stopCapture()
            } catch {
                #if DEBUG
                    print("[Locus] Error stopping stream: \(error)")
                #endif
            }
            self.stream = nil

            await outputHandler.finish()
            self.outputHandler = nil

            // Get video duration
            let asset = AVAsset(url: outputURL)
            let durationCMTime = try? await asset.load(.duration)
            let durationSeconds = durationCMTime.map { CMTimeGetSeconds($0) }

            // Get file size
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

            // Save to history
            let entry = HistoryStore.shared.saveVideo(
                videoURL: outputURL,
                appName: appName,
                windowTitle: windowTitle,
                fileSize: fileSize,
                duration: durationSeconds
            )

            Feedback.playSuccessSound()

            // Show export dialog
            if let entry {
                ExportView.present(entry: entry)
            }
        }
    }

    private func scaleFactorForPoint(_ point: NSPoint) -> CGFloat {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.screens.first
        return screen?.backingScaleFactor ?? 2.0
    }
}

// MARK: - Stream Output Handler

private final class StreamOutputHandler: NSObject, SCStreamOutput, SCStreamDelegate {
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private var sessionStarted = false
    private let lock = NSLock()

    init(outputURL: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
            ],
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        writer.add(audioInput)
    }

    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        lock.lock()
        defer { lock.unlock() }

        guard writer.status != .failed, writer.status != .cancelled else { return }

        if !sessionStarted {
            writer.startWriting()
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            sessionStarted = true
        }

        switch type {
        case .screen:
            if videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
            }
        case .audio:
            if audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
        case .microphone:
            break
        @unknown default:
            break
        }
    }

    func finish() async {
        markInputsFinished()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }
    }

    private func markInputsFinished() {
        lock.lock()
        videoInput.markAsFinished()
        audioInput.markAsFinished()
        lock.unlock()
    }

    func stream(_: SCStream, didStopWithError error: Error) {
        #if DEBUG
            print("[Locus] Stream stopped with error: \(error)")
        #endif
    }
}
