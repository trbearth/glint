import Foundation

struct GlintEvent: Codable, Identifiable {
    let id: UUID
    let source: String
    let title: String
    let detail: String
    let status: String
    let project: String?
    let projectPath: String?
    let appBundleIdentifier: String?
    let createdAt: Date

    init(source: String, title: String, detail: String, status: String = "success", project: String? = nil, projectPath: String? = nil, appBundleIdentifier: String? = nil) {
        self.id = UUID(); self.source = source; self.title = title; self.detail = detail
        self.status = status; self.project = project; self.projectPath = projectPath
        self.appBundleIdentifier = appBundleIdentifier; self.createdAt = Date()
    }
}

struct GlintConfig: Codable {
    var sound = "Glass"
    var theme = "brand"
    var position = "top-right"
    var duration = 0.0
    var enabled = true
    /// `doneOnly` only surfaces terminal completion events. `steps` also shows
    /// useful progress events emitted by supported session watchers.
    var notificationMode = "doneOnly"

    private enum CodingKeys: String, CodingKey { case sound, theme, position, duration, enabled, notificationMode }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sound = try values.decodeIfPresent(String.self, forKey: .sound) ?? "Glass"
        theme = try values.decodeIfPresent(String.self, forKey: .theme) ?? "brand"
        position = try values.decodeIfPresent(String.self, forKey: .position) ?? "top-right"
        duration = try values.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        notificationMode = try values.decodeIfPresent(String.self, forKey: .notificationMode) ?? "doneOnly"
    }
}

enum NotificationPolicy {
    /// Dismissals are control events and must always pass. In done-only mode,
    /// every adapter is restricted to terminal outcomes at the final display
    /// boundary so a new integration cannot accidentally leak progress cards.
    static func shouldDisplay(_ event: GlintEvent, mode: String) -> Bool {
        if event.status == "dismiss" { return true }
        if mode == "steps" { return true }
        return ["success", "failure", "cancelled", "canceled"].contains(event.status.lowercased())
    }
}

enum GlintPaths {
    static let root: URL = {
        if let override = ProcessInfo.processInfo.environment["GLINT_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Glint", isDirectory: true)
    }()
    static let events = root.appendingPathComponent("events.jsonl")
    static let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
    static let config = root.appendingPathComponent("config.json")

    static func prepare() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: inbox.path)
    }
}

enum EventQueue {
    static func push(_ event: GlintEvent) throws {
        try GlintPaths.prepare()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let destination = GlintPaths.inbox.appendingPathComponent("\(event.createdAt.timeIntervalSince1970)-\(event.id.uuidString).json")
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    /// Claims complete event files by atomically moving them out of the inbox.
    /// A producer can therefore never expose a partially-written JSON record.
    static func drain(limit: Int = 100) -> [GlintEvent] {
        try? GlintPaths.prepare()
        let manager = FileManager.default
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let urls = ((try? manager.contentsOfDirectory(at: GlintPaths.inbox,
                                                       includingPropertiesForKeys: [.contentModificationDateKey],
                                                       options: [.skipsHiddenFiles])) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .prefix(max(0, limit))
        var events: [GlintEvent] = []
        for url in urls {
            let claimed = url.deletingLastPathComponent().appendingPathComponent(".processing-\(UUID().uuidString)")
            guard (try? manager.moveItem(at: url, to: claimed)) != nil else { continue }
            defer { try? manager.removeItem(at: claimed) }
            if let data = try? Data(contentsOf: claimed),
               let event = try? decoder.decode(GlintEvent.self, from: data) { events.append(event) }
        }
        prune()
        return events
    }

    private static func prune() {
        let manager = FileManager.default
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        guard let urls = try? manager.contentsOfDirectory(at: GlintPaths.inbox,
                                                          includingPropertiesForKeys: [.contentModificationDateKey],
                                                          options: []) else { return }
        for url in urls where url.lastPathComponent.hasPrefix(".processing-") {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if modified < cutoff { try? manager.removeItem(at: url) }
        }
    }
}

enum ConfigStore {
    static func load() -> GlintConfig {
        guard let data = try? Data(contentsOf: GlintPaths.config), let value = try? JSONDecoder().decode(GlintConfig.self, from: data) else { return GlintConfig() }
        return value
    }
    static func save(_ config: GlintConfig) throws {
        try GlintPaths.prepare(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: GlintPaths.config, options: .atomic)
    }
}
