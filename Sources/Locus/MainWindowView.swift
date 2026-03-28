import SwiftUI

enum MainTab: Hashable {
    case history
    case settings
}

final class WindowState: ObservableObject {
    static let shared = WindowState()
    @Published var selectedTab: MainTab = .history
}

struct MainWindowView: View {
    @ObservedObject private var windowState = WindowState.shared

    var body: some View {
        TabView(selection: $windowState.selectedTab) {
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(MainTab.history)

            ScrollView {
                SettingsView()
                    .frame(maxWidth: 480, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(MainTab.settings)
        }
    }
}
