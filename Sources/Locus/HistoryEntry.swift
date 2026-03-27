import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let filename: String
    let appName: String?
    let windowTitle: String?
    let fileSize: Int64

    var displayName: String {
        appName ?? windowTitle ?? "Capture"
    }
}
