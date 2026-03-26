@testable import Locus
import XCTest

final class HotkeyBindingTests: XCTestCase {
    // MARK: - Display String

    func testDisplayStringCmdShiftW() {
        let binding = HotkeyBinding.defaultCaptureWindow
        XCTAssertEqual(binding.displayString, "\u{21E7}\u{2318}W")
    }

    func testDisplayStringCmdShiftF() {
        let binding = HotkeyBinding.defaultCaptureFullScreen
        XCTAssertEqual(binding.displayString, "\u{21E7}\u{2318}F")
    }

    func testDisplayStringCmdOnly() {
        let cmdFlag: UInt64 = 1_048_576 // .maskCommand
        let binding = HotkeyBinding(keyCode: 0, modifierFlags: cmdFlag, displayKey: "A")
        XCTAssertEqual(binding.displayString, "\u{2318}A")
    }

    func testDisplayStringAllModifiers() {
        // Ctrl + Option + Shift + Cmd
        let allFlags: UInt64 = 262_144 + 524_288 + 131_072 + 1_048_576
        let binding = HotkeyBinding(keyCode: 0, modifierFlags: allFlags, displayKey: "X")
        XCTAssertEqual(binding.displayString, "\u{2303}\u{2325}\u{21E7}\u{2318}X")
    }

    func testDisplayStringCtrlOnly() {
        let ctrlFlag: UInt64 = 262_144 // .maskControl
        let binding = HotkeyBinding(keyCode: 0, modifierFlags: ctrlFlag, displayKey: "Z")
        XCTAssertEqual(binding.displayString, "\u{2303}Z")
    }

    // MARK: - Matches

    func testMatchesExactKeyAndModifiers() {
        let binding = HotkeyBinding.defaultCaptureWindow // Cmd+Shift+W, keyCode 13
        let flags = CGEventFlags([.maskCommand, .maskShift])
        XCTAssertTrue(binding.matches(keyCode: 13, flags: flags))
    }

    func testDoesNotMatchWrongKeyCode() {
        let binding = HotkeyBinding.defaultCaptureWindow
        let flags = CGEventFlags([.maskCommand, .maskShift])
        XCTAssertFalse(binding.matches(keyCode: 5, flags: flags))
    }

    func testDoesNotMatchWrongModifiers() {
        let binding = HotkeyBinding.defaultCaptureWindow
        let flags = CGEventFlags([.maskCommand]) // missing Shift
        XCTAssertFalse(binding.matches(keyCode: 13, flags: flags))
    }

    func testMatchesIgnoresExtraDeviceFlags() {
        let binding = HotkeyBinding.defaultCaptureWindow
        // Simulates real CGEvent flags which include device-dependent bits
        var flags = CGEventFlags([.maskCommand, .maskShift])
        flags.insert(CGEventFlags(rawValue: 0x2000_0100)) // extra device flag
        XCTAssertTrue(binding.matches(keyCode: 13, flags: flags))
    }

    func testDoesNotMatchExtraModifier() {
        let binding = HotkeyBinding.defaultCaptureWindow // Cmd+Shift
        let flags = CGEventFlags([.maskCommand, .maskShift, .maskControl])
        XCTAssertFalse(binding.matches(keyCode: 13, flags: flags))
    }

    // MARK: - Codable

    func testEncodeDecode() throws {
        let original = HotkeyBinding.defaultCaptureWindow
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Equatable

    func testEqualBindings() {
        let lhs = HotkeyBinding(keyCode: 13, modifierFlags: 1_179_648, displayKey: "W")
        let rhs = HotkeyBinding(keyCode: 13, modifierFlags: 1_179_648, displayKey: "W")
        XCTAssertEqual(lhs, rhs)
    }

    func testUnequalBindings() {
        let window = HotkeyBinding.defaultCaptureWindow
        let fullScreen = HotkeyBinding.defaultCaptureFullScreen
        XCTAssertNotEqual(window, fullScreen)
    }
}
