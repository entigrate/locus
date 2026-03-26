import AppKit
import ServiceManagement

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var captureWindow: HotkeyBinding {
        didSet { saveBindings() }
    }

    @Published var captureFullScreen: HotkeyBinding {
        didSet { saveBindings() }
    }

    @Published var openHistory: HotkeyBinding {
        didSet { saveBindings() }
    }

    @Published var soundName: String {
        didSet { UserDefaults.standard.set(soundName, forKey: "soundName") }
    }

    @Published var soundVolume: Float {
        didSet { UserDefaults.standard.set(soundVolume, forKey: "soundVolume") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                #if DEBUG
                    print("[Locus] Launch at login error: \(error)")
                #endif
                let current = SMAppService.mainApp.status == .enabled
                if launchAtLogin != current {
                    launchAtLogin = current
                }
            }
        }
    }

    /// nil = unlimited, 0 = disabled, positive = limit. Default 10.
    @Published var historyLimit: Int? {
        didSet {
            UserDefaults.standard.set(historyLimit ?? -1, forKey: "historyLimit")
        }
    }

    var soundEnabled: Bool {
        !soundName.isEmpty
    }

    private init() {
        captureWindow = Self.loadBinding(key: "captureWindowHotkey") ?? .defaultCaptureWindow
        captureFullScreen = Self.loadBinding(key: "captureFullScreenHotkey") ?? .defaultCaptureFullScreen
        openHistory = Self.loadBinding(key: "openHistoryHotkey") ?? .defaultOpenHistory
        soundName = UserDefaults.standard.string(forKey: "soundName") ?? "Glass"
        soundVolume = UserDefaults.standard.object(forKey: "soundVolume") as? Float ?? 1.0
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if let raw = UserDefaults.standard.object(forKey: "historyLimit") as? Int {
            historyLimit = raw == -1 ? nil : raw
        } else {
            historyLimit = 10
        }
    }

    func resetToDefaults() {
        captureWindow = .defaultCaptureWindow
        captureFullScreen = .defaultCaptureFullScreen
        openHistory = .defaultOpenHistory
        soundName = "Glass"
        soundVolume = 1.0
        historyLimit = 10
    }

    private func saveBindings() {
        Self.storeBinding(captureWindow, key: "captureWindowHotkey")
        Self.storeBinding(captureFullScreen, key: "captureFullScreenHotkey")
        Self.storeBinding(openHistory, key: "openHistoryHotkey")
    }

    private static func loadBinding(key: String) -> HotkeyBinding? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }

    private static func storeBinding(_ binding: HotkeyBinding, key: String) {
        if let data = try? JSONEncoder().encode(binding) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
