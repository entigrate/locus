import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    enum MediaType: String, Codable {
        case screenshot
        case video
    }

    let id: UUID
    let timestamp: Date
    let filename: String
    let appName: String?
    let windowTitle: String?
    let fileSize: Int64
    let mediaType: MediaType
    let duration: TimeInterval?

    var displayName: String {
        appName ?? windowTitle ?? (mediaType == .video ? "Recording" : "Capture")
    }

    init(
        id: UUID,
        timestamp: Date,
        filename: String,
        appName: String?,
        windowTitle: String?,
        fileSize: Int64,
        mediaType: MediaType = .screenshot,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.filename = filename
        self.appName = appName
        self.windowTitle = windowTitle
        self.fileSize = fileSize
        self.mediaType = mediaType
        self.duration = duration
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, filename, appName, windowTitle, fileSize, mediaType, duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        filename = try container.decode(String.self, forKey: .filename)
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        windowTitle = try container.decodeIfPresent(String.self, forKey: .windowTitle)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        mediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType) ?? .screenshot
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(filename, forKey: .filename)
        try container.encodeIfPresent(appName, forKey: .appName)
        try container.encodeIfPresent(windowTitle, forKey: .windowTitle)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encodeIfPresent(duration, forKey: .duration)
    }
}
