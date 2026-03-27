import AppKit
import UniformTypeIdentifiers

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let historyDirectory: URL

    var totalDiskUsage: Int64 {
        entries.reduce(0) { $0 + $1.fileSize }
    }

    func fileURL(for entry: HistoryEntry) -> URL {
        historyDirectory.appendingPathComponent(entry.filename)
    }

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        historyDirectory = caches.appendingPathComponent("com.locus.app/history", isDirectory: true)
        loadManifest()
    }

    /// Test-only initializer
    init(directory: URL) {
        historyDirectory = directory
        loadManifest()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        return formatter
    }()

    func save(pngData: Data, appName: String?, windowTitle: String?) {
        let limit = SettingsStore.shared.historyLimit
        if limit == 0 { return }

        ensureDirectory()

        let filename = "\(Self.dateFormatter.string(from: Date())).png"
        let fileURL = historyDirectory.appendingPathComponent(filename)

        do {
            try pngData.write(to: fileURL)
        } catch {
            #if DEBUG
                print("[Locus] Failed to save history file: \(error)")
            #endif
            return
        }

        let entry = HistoryEntry(
            id: UUID(),
            timestamp: Date(),
            filename: filename,
            appName: appName,
            windowTitle: windowTitle,
            fileSize: Int64(pngData.count)
        )

        entries.insert(entry, at: 0)
        enforceLimit()
        saveManifest()
    }

    func delete(entry: HistoryEntry) {
        try? FileManager.default.removeItem(at: fileURL(for: entry))
        entries.removeAll { $0.id == entry.id }
        saveManifest()
    }

    func clearAll() {
        for entry in entries {
            try? FileManager.default.removeItem(at: fileURL(for: entry))
        }
        entries.removeAll()
        saveManifest()
    }

    func copyToClipboard(entry: HistoryEntry) -> Bool {
        guard let data = try? Data(contentsOf: fileURL(for: entry)) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
        return true
    }

    func saveToFile(entry: HistoryEntry) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedFilename(for: entry)
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try FileManager.default.copyItem(at: fileURL(for: entry), to: url)
        } catch {
            #if DEBUG
                print("[Locus] Failed to save file: \(error)")
            #endif
        }
    }

    private static let saveFileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        return formatter
    }()

    func itemProvider(for entry: HistoryEntry) -> NSItemProvider {
        let filename = suggestedFilename(for: entry)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("locus-drag")
        // Clean previous drag files to avoid unbounded temp growth
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempFile = tempDir.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: fileURL(for: entry), to: tempFile)
        } catch {
            #if DEBUG
                print("[Locus] Failed to create drag file: \(error)")
            #endif
            return NSItemProvider()
        }
        let provider = NSItemProvider(contentsOf: tempFile) ?? NSItemProvider()
        provider.suggestedName = (filename as NSString).deletingPathExtension
        return provider
    }

    func suggestedFilename(for entry: HistoryEntry) -> String {
        let appName = entry.displayName.replacingOccurrences(of: "/", with: "-")
        let dateString = Self.saveFileDateFormatter.string(from: entry.timestamp)
        return "Locus - \(appName) - \(dateString).png"
    }

    func enforceLimit() {
        guard let limit = SettingsStore.shared.historyLimit, limit >= 0, entries.count > limit else { return }
        let excess = entries.suffix(from: limit)
        for entry in excess {
            try? FileManager.default.removeItem(at: fileURL(for: entry))
        }
        entries.removeLast(entries.count - limit)
        saveManifest()
    }

    // MARK: - Manifest Persistence

    private var manifestURL: URL {
        historyDirectory.appendingPathComponent("manifest.json")
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func saveManifest() {
        ensureDirectory()
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL)
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
    }
}
