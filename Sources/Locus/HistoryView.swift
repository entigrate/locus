import AVFoundation
import AVKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared
    @State private var showClearConfirmation = false
    @State private var selectedEntry: HistoryEntry?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if store.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.entries) { entry in
                                HistoryCell(entry: entry) {
                                    selectedEntry = entry
                                }
                            }
                        }
                        .padding(16)
                    }
                }

                Divider()
                toolbar
            }

            if let entry = selectedEntry, let index = store.entries.firstIndex(where: { $0.id == entry.id }) {
                HistoryDetailView(
                    entries: store.entries,
                    currentIndex: index,
                    onSelect: { selectedEntry = store.entries[$0] },
                    onDismiss: { selectedEntry = nil }
                )
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .confirmationDialog(
            "Clear all capture history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                store.clearAll()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No captures yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Use \(SettingsStore.shared.captureWindow.displayString) to capture a window")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var toolbar: some View {
        HStack {
            Text("\(store.entries.count) captures \u{2014} \(formattedDiskUsage)")
                .font(.caption)
                .foregroundColor(.secondary)
            if let limit = SettingsStore.shared.historyLimit {
                Button("keeping last \(limit)") {
                    WindowState.shared.selectedTab = .settings
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            Spacer()
            Button("Clear All") {
                showClearConfirmation = true
            }
            .disabled(store.entries.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var formattedDiskUsage: String {
        ByteCountFormatter.string(fromByteCount: store.totalDiskUsage, countStyle: .file)
    }
}

// MARK: - Detail View

private struct HistoryDetailView: View {
    let entries: [HistoryEntry]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void
    @State private var fullImage: NSImage?
    @State private var videoPlayer: AVPlayer?

    private var entry: HistoryEntry {
        entries[currentIndex]
    }

    private var hasPrevious: Bool {
        currentIndex > 0
    }

    private var hasNext: Bool {
        currentIndex < entries.count - 1
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                // Previous arrow
                if hasPrevious {
                    navButton(systemImage: "chevron.left") { onSelect(currentIndex - 1) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                }

                // Next arrow
                if hasNext {
                    navButton(systemImage: "chevron.right") { onSelect(currentIndex + 1) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 12)
                }

                VStack(spacing: 16) {
                    mediaView
                        .frame(
                            maxWidth: geo.size.width - 120,
                            maxHeight: geo.size.height - 120
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 20)
                        .onDrag { HistoryStore.shared.itemProvider(for: entry) }

                    HStack(spacing: 8) {
                        Text(entry.displayName)
                            .fontWeight(.medium)
                        Text("\u{2014}")
                            .foregroundColor(.secondary)
                        Text(timeAgo(entry.timestamp))
                            .foregroundColor(.secondary)
                        if entry.mediaType == .video, let duration = entry.duration {
                            Text("\u{2014}")
                                .foregroundColor(.secondary)
                            Text(formatDuration(duration))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)

                    HStack(spacing: 12) {
                        Button {
                            if HistoryStore.shared.copyToClipboard(entry: entry) {
                                Feedback.playSuccessSound()
                            }
                        } label: {
                            Label("Copy", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderedProminent)

                        if entry.mediaType == .video {
                            Button {
                                onDismiss()
                                ExportView.present(entry: entry)
                            } label: {
                                Label("Export As\u{2026}", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            HistoryStore.shared.saveToFile(entry: entry)
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            HistoryStore.shared.delete(entry: entry)
                            onDismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(32)
            }
        }
        .onAppear { loadMedia() }
        .onChange(of: currentIndex) { _, _ in
            fullImage = nil
            videoPlayer?.pause()
            videoPlayer = nil
            loadMedia()
        }
        .onExitCommand { onDismiss() }
        .onKeyPress(.leftArrow) {
            if hasPrevious { onSelect(currentIndex - 1) }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if hasNext { onSelect(currentIndex + 1) }
            return .handled
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if entry.mediaType == .video {
            if let videoPlayer {
                PlayerView(player: videoPlayer)
            } else {
                ProgressView()
                    .frame(width: 200, height: 150)
            }
        } else if let fullImage {
            Image(nsImage: fullImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ProgressView()
                .frame(width: 200, height: 150)
        }
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func loadMedia() {
        if entry.mediaType == .video {
            let url = HistoryStore.shared.fileURL(for: entry)
            videoPlayer = AVPlayer(url: url)
        } else {
            let fileURL = HistoryStore.shared.fileURL(for: entry)
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = NSImage(contentsOf: fileURL) else { return }
                DispatchQueue.main.async { fullImage = image }
            }
        }
    }
}
