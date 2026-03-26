import SwiftUI

@main
struct LocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Locus", systemImage: "camera.viewfinder") {
            MenuContent(appDelegate: appDelegate)
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

            Button("Settings\u{2026}") {
                openWindow(id: "settings")
                NSApp.activate()
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
