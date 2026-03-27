@testable import Locus
import XCTest

final class SettingsStoreTests: XCTestCase {
    // MARK: - Defaults

    func testDefaultCaptureWindowBinding() {
        let store = SettingsStore.shared
        let defaultBinding = HotkeyBinding.defaultCaptureWindow
        // Verify the default key code and modifiers are correct for Cmd+Shift+1
        XCTAssertEqual(defaultBinding.keyCode, 18) // 1 key
        XCTAssertEqual(defaultBinding.displayKey, "1")
        XCTAssertEqual(defaultBinding.displayString, "\u{21E7}\u{2318}1")
        // Store should have a valid binding (either default or user-configured)
        XCTAssertGreaterThan(store.captureWindow.modifierFlags, 0)
    }

    func testDefaultCaptureFullScreenBinding() {
        let defaultBinding = HotkeyBinding.defaultCaptureFullScreen
        XCTAssertEqual(defaultBinding.keyCode, 19) // 2 key
        XCTAssertEqual(defaultBinding.displayKey, "2")
        XCTAssertEqual(defaultBinding.displayString, "\u{21E7}\u{2318}2")
    }

    func testDefaultSoundName() {
        // After reset, sound should be Glass
        let store = SettingsStore.shared
        store.resetToDefaults()
        XCTAssertEqual(store.soundName, "Glass")
    }

    func testDefaultSoundVolume() {
        let store = SettingsStore.shared
        store.resetToDefaults()
        XCTAssertEqual(store.soundVolume, 1.0, accuracy: 0.01)
    }

    // MARK: - Sound Enabled

    func testSoundEnabledWhenNameSet() {
        let store = SettingsStore.shared
        store.soundName = "Glass"
        XCTAssertTrue(store.soundEnabled)
    }

    func testSoundDisabledWhenNameEmpty() {
        let store = SettingsStore.shared
        store.soundName = ""
        XCTAssertFalse(store.soundEnabled)
        // Restore default
        store.soundName = "Glass"
    }

    // MARK: - Reset

    func testResetToDefaults() {
        let store = SettingsStore.shared
        // Modify everything
        store.soundName = "Pop"
        store.soundVolume = 0.5
        store.captureWindow = HotkeyBinding(keyCode: 0, modifierFlags: 1_048_576, displayKey: "A")

        // Reset
        store.resetToDefaults()

        XCTAssertEqual(store.captureWindow, HotkeyBinding.defaultCaptureWindow)
        XCTAssertEqual(store.captureFullScreen, HotkeyBinding.defaultCaptureFullScreen)
        XCTAssertEqual(store.soundName, "Glass")
        XCTAssertEqual(store.soundVolume, 1.0, accuracy: 0.01)
    }

    // MARK: - Persistence

    func testSoundNamePersistence() {
        let store = SettingsStore.shared
        store.soundName = "Ping"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "soundName"), "Ping")
        // Restore
        store.resetToDefaults()
    }

    func testSoundVolumePersistence() {
        let store = SettingsStore.shared
        store.soundVolume = 0.42
        XCTAssertEqual(UserDefaults.standard.float(forKey: "soundVolume"), 0.42, accuracy: 0.01)
        // Restore
        store.resetToDefaults()
    }
}
