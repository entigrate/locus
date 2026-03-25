import SwiftUI

@main
struct GlimpseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Glimpse", systemImage: "camera.viewfinder") {
            MenuContent(appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    let appDelegate: AppDelegate
    @State private var hotkeyReady = false

    var body: some View {
        Group {
            if hotkeyReady {
                Button("Capture Window  \u{2318}\u{21E7}G") {
                    AppDelegate.performCapture()
                }
            } else {
                Text("Waiting for Accessibility permission...")
                    .foregroundColor(.secondary)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Divider()

            Button("Quit Glimpse") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onReceive(NotificationCenter.default.publisher(for: .glimpseStatusChanged)) { _ in
            hotkeyReady = appDelegate.hotkeyReady
        }
        .onAppear {
            hotkeyReady = appDelegate.hotkeyReady
        }
    }
}
