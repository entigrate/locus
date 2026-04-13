import AppKit

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt64
    var displayKey: String

    static let defaultCaptureWindow = HotkeyBinding(keyCode: 18, modifierFlags: 1_179_648, displayKey: "1")
    static let defaultCaptureFullScreen = HotkeyBinding(keyCode: 19, modifierFlags: 1_179_648, displayKey: "2")
    static let defaultOpenHistory = HotkeyBinding(keyCode: 4, modifierFlags: 1_179_648, displayKey: "H")
    static let defaultRecordWindow = HotkeyBinding(keyCode: 18, modifierFlags: 1_572_864, displayKey: "1")
    static let defaultRecordFullScreen = HotkeyBinding(keyCode: 19, modifierFlags: 1_572_864, displayKey: "2")

    var displayString: String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifierFlags)
        if flags.contains(.maskControl) { parts.append("\u{2303}") }
        if flags.contains(.maskAlternate) { parts.append("\u{2325}") }
        if flags.contains(.maskShift) { parts.append("\u{21E7}") }
        if flags.contains(.maskCommand) { parts.append("\u{2318}") }
        parts.append(displayKey)
        return parts.joined()
    }

    func matches(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        let masked = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])
        return self.keyCode == keyCode && masked == CGEventFlags(rawValue: modifierFlags)
    }
}
