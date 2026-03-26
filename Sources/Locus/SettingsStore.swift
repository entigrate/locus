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

    var soundEnabled: Bool {
        !soundName.isEmpty
    }

    private init() {
        captureWindow = Self.loadBinding(key: "captureWindowHotkey") ?? .defaultCaptureWindow
        captureFullScreen = Self.loadBinding(key: "captureFullScreenHotkey") ?? .defaultCaptureFullScreen
        soundName = UserDefaults.standard.string(forKey: "soundName") ?? "Glass"
        soundVolume = UserDefaults.standard.object(forKey: "soundVolume") as? Float ?? 1.0
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func resetToDefaults() {
        captureWindow = .defaultCaptureWindow
        captureFullScreen = .defaultCaptureFullScreen
        soundName = "Glass"
        soundVolume = 1.0
    }

    private func saveBindings() {
        Self.storeBinding(captureWindow, key: "captureWindowHotkey")
        Self.storeBinding(captureFullScreen, key: "captureFullScreenHotkey")
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
