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
                    imageView
                        .frame(
                            maxWidth: geo.size.width - 120,
                            maxHeight: geo.size.height - 120
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 20)

                    HStack(spacing: 8) {
                        Text(entry.appName ?? entry.windowTitle ?? "Capture")
                            .fontWeight(.medium)
                        Text("\u{2014}")
                            .foregroundColor(.secondary)
                        Text(timeAgo(entry.timestamp))
                            .foregroundColor(.secondary)
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
        .onAppear { loadFullImage() }
        .onChange(of: currentIndex) { _, _ in
            fullImage = nil
            loadFullImage()
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
    private var imageView: some View {
        if let fullImage {
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

    private func loadFullImage() {
        let fileURL = HistoryStore.shared.fileURL(for: entry)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOf: fileURL) else { return }
            DispatchQueue.main.async { fullImage = image }
        }
    }
}

// MARK: - Grid Cell

private struct HistoryCell: View {
    let entry: HistoryEntry
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                thumbnailView
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture { onSelect() }

                if isHovered {
                    hoverActions
                }
            }

            Text(entry.appName ?? entry.windowTitle ?? "Capture")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(timeAgo(entry.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnail() }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .overlay {
                    ProgressView()
                        .scaleEffect(0.5)
                }
        }
    }

    private var hoverActions: some View {
        HStack(spacing: 4) {
            Button {
                if HistoryStore.shared.copyToClipboard(entry: entry) {
                    Feedback.playSuccessSound()
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
                    .padding(6)
                    .background(.ultraThickMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                HistoryStore.shared.delete(entry: entry)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .padding(6)
                    .background(.ultraThickMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(6)
    }

    private func loadThumbnail() {
        let fileURL = HistoryStore.shared.fileURL(for: entry)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOf: fileURL) else { return }
            let thumbSize = NSSize(width: 320, height: 320)
            let thumb = NSImage(size: thumbSize, flipped: false) { rect in
                image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
                return true
            }
            DispatchQueue.main.async {
                thumbnail = thumb
            }
        }
    }
}

private func timeAgo(_ date: Date) -> String {
    let seconds = Int(-date.timeIntervalSinceNow)
    switch seconds {
    case ..<5: return "just now"
    case ..<60: return "\(seconds) seconds ago"
    case ..<120: return "1 minute ago"
    case ..<3600: return "\(seconds / 60) minutes ago"
    case ..<7200: return "1 hour ago"
    case ..<86400: return "\(seconds / 3600) hours ago"
    case ..<172_800: return "yesterday"
    default: return "\(seconds / 86400) days ago"
    }
}
