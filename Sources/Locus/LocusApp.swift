import Sparkle
import SwiftUI

@main
struct LocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    @ObservedObject private var recorder = VideoRecorder.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(appDelegate: appDelegate, checkForUpdates: updaterController.updater.checkForUpdates)
        } label: {
            Image(systemName: recorder.isRecording ? "record.circle" : "camera.viewfinder")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    let appDelegate: AppDelegate
    let checkForUpdates: () -> Void
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var recorder = VideoRecorder.shared
    @State private var hotkeyReady = false

    var body: some View {
        Group {
            if recorder.isRecording {
                Button("Stop Recording  \(recorder.formattedElapsedTime)") {
                    VideoRecorder.shared.stopRecording()
                }
                Divider()
            }

            if hotkeyReady {
                Button("Capture Window  \(store.captureWindow.displayString)") {
                    AppDelegate.performWindowCapture()
                }
                .disabled(recorder.isRecording)

                Button("Capture Full Screen  \(store.captureFullScreen.displayString)") {
                    AppDelegate.performFullScreenCapture()
                }
                .disabled(recorder.isRecording)

                Divider()

                if !recorder.isRecording {
                    Button("Record Window  \(store.recordWindow.displayString)") {
                        Task { await VideoRecorder.shared.startWindowRecording() }
                    }
                    Button("Record Full Screen  \(store.recordFullScreen.displayString)") {
                        Task { await VideoRecorder.shared.startFullScreenRecording() }
                    }
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
                DispatchQueue.main.async {
                    AppDelegate.openMainWindow(tab: .settings)
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
