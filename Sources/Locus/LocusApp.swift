import Sparkle
import SwiftUI

@main
struct LocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        MenuBarExtra("Locus", systemImage: "camera.viewfinder") {
            MenuContent(appDelegate: appDelegate, checkForUpdates: updaterController.updater.checkForUpdates)
        }
        .menuBarExtraStyle(.menu)

        Window("Locus Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct MenuContent: View {
    let appDelegate: AppDelegate
    let checkForUpdates: () -> Void
    @ObservedObject private var store = SettingsStore.shared
    @Environment(\.openWindow) private var openWindow
    @State private var hotkeyReady = false

    var body: some View {
        Group {
            if hotkeyReady {
                Button("Capture Window  \(store.captureWindow.displayString)") {
                    AppDelegate.performWindowCapture()
                }
                Button("Capture Full Screen  \(store.captureFullScreen.displayString)") {
                    AppDelegate.performFullScreenCapture()
                }
            } else {
                Text("Waiting for Accessibility permission\u{2026}")
                    .foregroundColor(.secondary)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Divider()

            Button("History  \(store.openHistory.displayString)") {
                // Async dispatch lets the menu dismiss before the window appears
                DispatchQueue.main.async {
                    AppDelegate.openHistoryWindow()
                }
            }

            Button("Check for Updates\u{2026}") {
                checkForUpdates()
            }

            Button("Settings\u{2026}") {
                DispatchQueue.main.async { [openWindow] in
                    NSApp.activate()
                    openWindow(id: "settings")
                }
            }

            Button("Quit Locus") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onReceive(NotificationCenter.default.publisher(for: .locusStatusChanged)) { _ in
            hotkeyReady = appDelegate.hotkeyReady
        }
        .onAppear {
            hotkeyReady = appDelegate.hotkeyReady
        }
    }
}
