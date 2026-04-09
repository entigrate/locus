import AVFoundation
import AVKit
import SwiftUI

struct ExportView: View {
    let entry: HistoryEntry
    @State private var format: ExportFormat = .mp4
    @State private var includeAudio = false
    @State private var gifQuality: GIFExporter.Quality = .medium
    @State private var isExporting = false
    @State private var player: AVPlayer?

    enum ExportFormat: String, CaseIterable {
        case mp4 = "MP4"
        case gif = "GIF"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Video preview using AppKit's AVPlayerView (SwiftUI VideoPlayer crashes on macOS)
            if let player {
                PlayerView(player: player)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Format selection
            HStack {
                Text("Format")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $format) {
                    ForEach(ExportFormat.allCases, id: \.self) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // Format-specific options
            if format == .mp4 {
                HStack {
                    Text("Include Audio")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $includeAudio)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .frame(width: 120, alignment: .trailing)
                }
            } else {
                HStack {
                    Text("Quality")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("", selection: $gifQuality) {
                        ForEach(GIFExporter.Quality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
            }

            // Info
            HStack {
                if let duration = entry.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(ByteCountFormatter.string(fromByteCount: entry.fileSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Actions
            HStack(spacing: 12) {
                Spacer()

                Button(role: .destructive) {
                    HistoryStore.shared.delete(entry: entry)
                    Self.close()
                } label: {
                    Text("Delete")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await saveAs() }
                } label: {
                    Text("Save As\u{2026}")
                }
                .buttonStyle(.bordered)
                .disabled(isExporting)

                Button {
                    Task { await copyToClipboard() }
                } label: {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 40)
                    } else {
                        Text("Copy")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
        .padding(24)
        .frame(width: 500)
        .onAppear {
            let url = HistoryStore.shared.fileURL(for: entry)
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Export

    private func exportFile() async throws -> URL {
        let sourceURL = HistoryStore.shared.fileURL(for: entry)
        switch format {
        case .mp4:
            if includeAudio {
                return sourceURL
            } else {
                return try await VideoExporter.exportMP4WithoutAudio(from: sourceURL)
            }
        case .gif:
            let data = try await GIFExporter.exportGIF(from: sourceURL, quality: gifQuality)
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("locus-export")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let url = tempDir.appendingPathComponent("\(UUID().uuidString).gif")
            try data.write(to: url)
            return url
        }
    }

    private func copyToClipboard() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await exportFile()
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSURL])
            Feedback.playSuccessSound()
            Self.close()
        } catch {
            #if DEBUG
                print("[Locus] Export failed: \(error)")
            #endif
            Feedback.captureFailure()
        }
    }

    private func saveAs() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let exportedURL = try await exportFile()
            let panel = NSSavePanel()
            panel.allowedContentTypes = format == .gif ? [.gif] : [.mpeg4Movie]
            let ext = format == .gif ? "gif" : "mp4"
            let appName = entry.displayName.replacingOccurrences(of: "/", with: "-")
            panel.nameFieldStringValue = "Locus - \(appName).\(ext)"
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK, let saveURL = panel.url else { return }

            let sourceURL = HistoryStore.shared.fileURL(for: entry)
            if exportedURL == sourceURL {
                try FileManager.default.copyItem(at: exportedURL, to: saveURL)
            } else {
                try FileManager.default.moveItem(at: exportedURL, to: saveURL)
            }
            Self.close()
        } catch {
            #if DEBUG
                print("[Locus] Save failed: \(error)")
            #endif
            Feedback.captureFailure()
        }
    }

    // MARK: - Window Presentation

    private static var exportWindow: NSWindow?
    private static let windowDelegate = ExportWindowDelegate()

    static func present(entry: HistoryEntry) {
        exportWindow?.close()

        NSApp.setActivationPolicy(.regular)
        let controller = NSHostingController(rootView: ExportView(entry: entry))
        let window = NSWindow(contentViewController: controller)
        window.title = "Export Recording"
        window.styleMask = [.titled, .closable]
        window.center()
        window.delegate = windowDelegate
        exportWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        exportWindow?.close()
    }

    private class ExportWindowDelegate: NSObject, NSWindowDelegate {
        func windowWillClose(_: Notification) {
            ExportView.exportWindow = nil
            // Revert to accessory if main window isn't open
            if !AppDelegate.isMainWindowVisible {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context _: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context _: Context) {
        nsView.player = player
    }
}
