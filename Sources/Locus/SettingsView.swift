import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.bottom, 16)

            ShortcutRow(label: "Capture Window", binding: $store.captureWindow, conflictsWith: [store.captureFullScreen, store.openHistory])
            Divider().padding(.vertical, 8)
            ShortcutRow(label: "Capture Full Screen", binding: $store.captureFullScreen, conflictsWith: [store.captureWindow, store.openHistory])
            Divider().padding(.vertical, 8)
            ShortcutRow(label: "Open History", binding: $store.openHistory, conflictsWith: [store.captureWindow, store.captureFullScreen])

            Spacer().frame(height: 24)

            Text("Sound")
                .font(.headline)
                .padding(.bottom, 16)

            SoundPicker(soundName: $store.soundName, volume: $store.soundVolume)

            Spacer().frame(height: 24)

            Text("General")
                .font(.headline)
                .padding(.bottom, 16)

            Toggle("Launch at Login", isOn: $store.launchAtLogin)

            Spacer().frame(height: 24)

            Text("History")
                .font(.headline)
                .padding(.bottom, 16)

            HistorySettingsSection()

            Spacer().frame(height: 24)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    store.resetToDefaults()
                }
            }
        }
        .padding(24)
        .frame(width: 380, height: 540)
    }
}

private struct ShortcutRow: View {
    let label: String
    @Binding var binding: HotkeyBinding
    let conflictsWith: [HotkeyBinding]

    var body: some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            ShortcutRecorder(binding: $binding, conflictsWith: conflictsWith)
        }
    }
}

private struct ShortcutRecorder: View {
    @Binding var binding: HotkeyBinding
    let conflictsWith: [HotkeyBinding]
    @State private var isRecording = false
    @State private var showConflict = false
    @State private var monitor: Any?

    var body: some View {
        Text(isRecording ? "Press shortcut\u{2026}" : binding.displayString)
            .font(.system(.body, design: .rounded).weight(.medium))
            .frame(minWidth: 100)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture { startRecording() }
            .onDisappear { stopRecording() }
            .popover(isPresented: $showConflict) {
                Text("Already used by another shortcut")
                    .padding(8)
            }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        HotkeyManager.shared.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged],
            handler: { event in
                if event.type == .keyDown {
                    if event.keyCode == 53 { // Escape
                        stopRecording()
                        return nil
                    }
                    let mods = event.modifierFlags.intersection([.command, .shift, .control, .option])
                    guard mods.contains(.command) || mods.contains(.control) else {
                        return nil // require Cmd or Ctrl
                    }
                    let key = displayKeyForEvent(event)
                    let candidate = HotkeyBinding(
                        keyCode: event.keyCode,
                        modifierFlags: UInt64(mods.rawValue),
                        displayKey: key
                    )
                    if conflictsWith.contains(candidate) {
                        showConflict = true
                        stopRecording()
                        return nil
                    }
                    binding = candidate
                    stopRecording()
                    return nil
                }
                return event
            }
        )
    }

    private func stopRecording() {
        isRecording = false
        HotkeyManager.shared.isRecordingShortcut = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

private struct SoundPicker: View {
    @Binding var soundName: String
    @Binding var volume: Float

    private static let systemSounds: [String] = {
        let url = URL(fileURLWithPath: "/System/Library/Sounds")
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "aiff" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Capture sound")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $soundName) {
                    Text("None").tag("")
                    Divider()
                    ForEach(Self.systemSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .onChange(of: soundName) { _, newValue in
                    previewSound(newValue)
                }
            }

            if !soundName.isEmpty {
                HStack {
                    Text("Volume")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Slider(value: $volume, in: 0 ... 1) { editing in
                        if !editing {
                            previewSound(soundName)
                        }
                    }
                    .frame(width: 140)
                }
            }
        }
    }

    private func previewSound(_ name: String) {
        guard !name.isEmpty, let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = volume
        sound.play()
    }
}

private struct HistorySettingsSection: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var historyStore = HistoryStore.shared
    @State private var limitText: String = ""
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Max captures")
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("unlimited", text: $limitText)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onSubmit { applyLimit() }
                    .onChange(of: store.historyLimit) { _, _ in syncLimitText() }
            }

            HStack {
                Text("0 = disabled, blank = unlimited")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack {
                Text(diskUsageText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear History") {
                    showClearConfirmation = true
                }
                .disabled(historyStore.entries.isEmpty)
                .confirmationDialog(
                    "Clear all capture history?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear All", role: .destructive) {
                        historyStore.clearAll()
                    }
                }
            }
        }
        .onAppear { syncLimitText() }
    }

    private var diskUsageText: String {
        let size = ByteCountFormatter.string(fromByteCount: historyStore.totalDiskUsage, countStyle: .file)
        return "\(historyStore.entries.count) captures \u{2014} \(size)"
    }

    private func syncLimitText() {
        if let limit = store.historyLimit {
            limitText = "\(limit)"
        } else {
            limitText = ""
        }
    }

    private func applyLimit() {
        let trimmed = limitText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            store.historyLimit = nil
        } else if let value = Int(trimmed), value >= 0 {
            store.historyLimit = value
            HistoryStore.shared.enforceLimit()
        } else {
            syncLimitText()
        }
    }
}

private let specialKeyCodes: [UInt16: String] = [
    122: "F1", 120: "F2", 99: "F3", 118: "F4",
    96: "F5", 97: "F6", 98: "F7", 100: "F8",
    101: "F9", 109: "F10", 103: "F11", 111: "F12",
    123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
]

private func displayKeyForEvent(_ event: NSEvent) -> String {
    guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
        return specialKeyCodes[event.keyCode] ?? "?"
    }
    guard let scalar = chars.unicodeScalars.first else {
        return specialKeyCodes[event.keyCode] ?? "?"
    }
    switch scalar.value {
    case 0x0D: return "\u{21A9}"
    case 0x09: return "\u{21E5}"
    case 0x20: return "Space"
    case 0x7F: return "\u{232B}"
    default:
        let upper = chars.uppercased()
        if upper.first?.isASCII == true { return upper }
        return specialKeyCodes[event.keyCode] ?? "?"
    }
}
