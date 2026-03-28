import AVFoundation
import SwiftUI

struct HistoryCell: View {
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
                    .overlay {
                        if entry.mediaType == .video {
                            ZStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)

                                if let duration = entry.duration {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Text(formatDuration(duration))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(4)
                                }
                            }
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture { onSelect() }
                    .onDrag { HistoryStore.shared.itemProvider(for: entry) }

                if isHovered {
                    hoverActions
                }
            }

            Text(entry.displayName)
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
            hoverButton(systemImage: "doc.on.clipboard") {
                if HistoryStore.shared.copyToClipboard(entry: entry) {
                    Feedback.playSuccessSound()
                }
            }
            hoverButton(systemImage: "square.and.arrow.down") {
                HistoryStore.shared.saveToFile(entry: entry)
            }
            hoverButton(systemImage: "trash") {
                HistoryStore.shared.delete(entry: entry)
            }
        }
        .padding(6)
    }

    private func hoverButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption)
                .padding(6)
                .background(.ultraThickMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func loadThumbnail() {
        let fileURL = HistoryStore.shared.fileURL(for: entry)
        let isVideo = entry.mediaType == .video
        DispatchQueue.global(qos: .userInitiated).async {
            let image: NSImage?
            if isVideo {
                let asset = AVAsset(url: fileURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 320, height: 320)
                if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                    image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                } else {
                    image = nil
                }
            } else {
                image = NSImage(contentsOf: fileURL)
            }
            guard let image else { return }
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

func timeAgo(_ date: Date) -> String {
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

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let mins = total / 60
    let secs = total % 60
    return String(format: "%d:%02d", mins, secs)
}
