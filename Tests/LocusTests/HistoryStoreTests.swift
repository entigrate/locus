@testable import Locus
import XCTest

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: HistoryStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = HistoryStore(directory: tempDir)
        // Ensure history is enabled for most tests
        SettingsStore.shared.historyLimit = 100
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        SettingsStore.shared.historyLimit = 10
        super.tearDown()
    }

    private var samplePNG: Data {
        // Minimal valid PNG (1x1 white pixel)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            return Data()
        }
        return png
    }

    // MARK: - Save

    func testSaveCreatesFile() {
        store.save(pngData: samplePNG, appName: "Safari", windowTitle: "Test")

        XCTAssertEqual(store.entries.count, 1)
        let entry = store.entries[0]
        let fileURL = tempDir.appendingPathComponent(entry.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSaveStoresMetadata() {
        store.save(pngData: samplePNG, appName: "Safari", windowTitle: "Google")

        let entry = store.entries[0]
        XCTAssertEqual(entry.appName, "Safari")
        XCTAssertEqual(entry.windowTitle, "Google")
        XCTAssertGreaterThan(entry.fileSize, 0)
    }

    func testSaveInsertsNewestFirst() {
        store.save(pngData: samplePNG, appName: "First", windowTitle: nil)
        store.save(pngData: samplePNG, appName: "Second", windowTitle: nil)

        XCTAssertEqual(store.entries[0].appName, "Second")
        XCTAssertEqual(store.entries[1].appName, "First")
    }

    // MARK: - Delete

    func testDeleteRemovesFileAndEntry() {
        store.save(pngData: samplePNG, appName: "Test", windowTitle: nil)
        let entry = store.entries[0]
        let fileURL = tempDir.appendingPathComponent(entry.filename)

        store.delete(entry: entry)

        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Clear All

    func testClearAllRemovesEverything() {
        store.save(pngData: samplePNG, appName: "One", windowTitle: nil)
        store.save(pngData: samplePNG, appName: "Two", windowTitle: nil)
        let filenames = store.entries.map(\.filename)

        store.clearAll()

        XCTAssertTrue(store.entries.isEmpty)
        for filename in filenames {
            XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent(filename).path))
        }
    }

    // MARK: - Limit Enforcement

    func testEnforceLimitRemovesOldest() {
        SettingsStore.shared.historyLimit = 3
        for idx in 0 ..< 5 {
            store.save(pngData: samplePNG, appName: "App\(idx)", windowTitle: nil)
        }

        XCTAssertEqual(store.entries.count, 3)
        // Newest should remain
        XCTAssertEqual(store.entries[0].appName, "App4")
        XCTAssertEqual(store.entries[1].appName, "App3")
        XCTAssertEqual(store.entries[2].appName, "App2")
    }

    func testEnforceLimitDeletesExcessFiles() {
        SettingsStore.shared.historyLimit = 100
        for idx in 0 ..< 5 {
            store.save(pngData: samplePNG, appName: "App\(idx)", windowTitle: nil)
            Thread.sleep(forTimeInterval: 0.01)
        }
        let allFilenames = store.entries.map(\.filename)

        SettingsStore.shared.historyLimit = 2
        store.enforceLimit()

        let remainingFilenames = Set(store.entries.map(\.filename))
        for filename in allFilenames {
            let exists = FileManager.default.fileExists(atPath: tempDir.appendingPathComponent(filename).path)
            if remainingFilenames.contains(filename) {
                XCTAssertTrue(exists, "Kept file should still exist: \(filename)")
            } else {
                XCTAssertFalse(exists, "Excess file should be deleted: \(filename)")
            }
        }
    }

    func testDisabledHistoryDoesNotSave() {
        SettingsStore.shared.historyLimit = 0
        store.save(pngData: samplePNG, appName: "Test", windowTitle: nil)

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testUnlimitedHistoryDoesNotTrim() {
        SettingsStore.shared.historyLimit = nil
        for idx in 0 ..< 20 {
            store.save(pngData: samplePNG, appName: "App\(idx)", windowTitle: nil)
        }

        XCTAssertEqual(store.entries.count, 20)
    }

    // MARK: - Disk Usage

    func testDiskUsageCalculation() {
        store.save(pngData: samplePNG, appName: "Test", windowTitle: nil)

        XCTAssertEqual(store.totalDiskUsage, Int64(samplePNG.count))
    }

    // MARK: - Manifest Persistence

    func testManifestPersistence() {
        store.save(pngData: samplePNG, appName: "Persisted", windowTitle: "Title")

        // Create a new store pointing at the same directory
        let reloaded = HistoryStore(directory: tempDir)

        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries[0].appName, "Persisted")
        XCTAssertEqual(reloaded.entries[0].windowTitle, "Title")
    }

    // MARK: - Display Name

    func testDisplayNamePrefersAppName() {
        let entry = HistoryEntry(id: UUID(), timestamp: Date(), filename: "test.png", appName: "Safari", windowTitle: "Google", fileSize: 0)
        XCTAssertEqual(entry.displayName, "Safari")
    }

    func testDisplayNameFallsBackToWindowTitle() {
        let entry = HistoryEntry(id: UUID(), timestamp: Date(), filename: "test.png", appName: nil, windowTitle: "My Window", fileSize: 0)
        XCTAssertEqual(entry.displayName, "My Window")
    }

    func testDisplayNameFallsBackToCapture() {
        let entry = HistoryEntry(id: UUID(), timestamp: Date(), filename: "test.png", appName: nil, windowTitle: nil, fileSize: 0)
        XCTAssertEqual(entry.displayName, "Capture")
    }

    // MARK: - Suggested Filename

    func testSuggestedFilenameWithAppName() {
        store.save(pngData: samplePNG, appName: "Safari", windowTitle: "Google")
        let entry = store.entries[0]

        let filename = store.suggestedFilename(for: entry)

        XCTAssertTrue(filename.hasPrefix("Locus - Safari - "))
        XCTAssertTrue(filename.hasSuffix(".png"))
    }

    func testSuggestedFilenameWithoutAppName() {
        store.save(pngData: samplePNG, appName: nil, windowTitle: "My Window")
        let entry = store.entries[0]

        let filename = store.suggestedFilename(for: entry)

        XCTAssertTrue(filename.hasPrefix("Locus - My Window - "))
        XCTAssertTrue(filename.hasSuffix(".png"))
    }

    func testSuggestedFilenameFallback() {
        store.save(pngData: samplePNG, appName: nil, windowTitle: nil)
        let entry = store.entries[0]

        let filename = store.suggestedFilename(for: entry)

        XCTAssertTrue(filename.hasPrefix("Locus - Capture - "))
        XCTAssertTrue(filename.hasSuffix(".png"))
    }

    func testSuggestedFilenameContainsDate() {
        store.save(pngData: samplePNG, appName: "Test", windowTitle: nil)
        let entry = store.entries[0]

        let filename = store.suggestedFilename(for: entry)

        // Should contain "at" from the date format "yyyy-MM-dd at h.mm.ss a"
        XCTAssertTrue(filename.contains(" at "))
    }

    // MARK: - Item Provider

    func testItemProviderCreatesTempFileWithCorrectName() {
        store.save(pngData: samplePNG, appName: "Safari", windowTitle: nil)
        let entry = store.entries[0]

        let provider = store.itemProvider(for: entry)

        XCTAssertNotNil(provider.suggestedName)
        XCTAssertTrue(provider.suggestedName?.hasPrefix("Locus - Safari - ") ?? false)
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier("public.png"))
    }

    // MARK: - Copy to Clipboard

    func testCopyToClipboard() {
        store.save(pngData: samplePNG, appName: "Test", windowTitle: nil)
        let entry = store.entries[0]

        let success = store.copyToClipboard(entry: entry)

        XCTAssertTrue(success)
        let pasteboardData = NSPasteboard.general.data(forType: .png)
        XCTAssertNotNil(pasteboardData)
    }
}
