import Foundation

final class CodexDesktopWatcher {
    private struct FileState {
        var offset: UInt64
        var cwd: String?
        var appBundleIdentifier: String?
        var remainder = Data()
    }

    private let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
    private var files: [URL: FileState] = [:]
    private var lastDiscovery = Date.distantPast
    private let launchedAt = Date()

    init() { discover(primeExisting: true) }

    func poll(notificationMode: String = "doneOnly") -> [GlintEvent] {
        if Date().timeIntervalSince(lastDiscovery) > 3 { discover(primeExisting: false) }
        var events: [GlintEvent] = []
        for url in Array(files.keys) {
            guard var state = files[url], let handle = try? FileHandle(forReadingFrom: url) else { continue }
            try? handle.seek(toOffset: state.offset)
            let fresh = (try? handle.readToEnd()) ?? Data(); try? handle.close()
            guard !fresh.isEmpty else { continue }
            state.offset += UInt64(fresh.count)
            var combined = state.remainder; combined.append(fresh)
            let hasTrailingNewline = combined.last == 0x0a
            var lines = [UInt8](combined).split(separator: 0x0a, omittingEmptySubsequences: true).map { Data($0) }
            state.remainder = (!hasTrailingNewline && !lines.isEmpty) ? lines.removeLast() : Data()

            for line in lines {
                guard let root = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let payload = root["payload"] as? [String: Any] else { continue }
                if root["type"] as? String == "session_meta" {
                    state.cwd = payload["cwd"] as? String
                    state.appBundleIdentifier = Self.bundleIdentifier(for: payload["originator"] as? String,
                                                                      source: payload["source"])
                    continue
                }
                guard state.appBundleIdentifier != nil, root["type"] as? String == "event_msg", let type = payload["type"] as? String else { continue }
                if type == "user_message" {
                    events.append(GlintEvent(source: "system", title: "Dismiss", detail: "New prompt started", status: "dismiss"))
                } else if notificationMode == "steps", type == "agent_message",
                          let message = payload["message"] as? String {
                    let path = state.cwd
                    events.append(GlintEvent(source: "codex", title: "Codex progress",
                                             detail: String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180)),
                                             status: "progress",
                                             project: path.map { URL(fileURLWithPath: $0).lastPathComponent },
                                             projectPath: path, appBundleIdentifier: state.appBundleIdentifier))
                } else if type == "task_complete" {
                    let path = state.cwd
                    let project = path.map { URL(fileURLWithPath: $0).lastPathComponent }
                    let message = ((payload["last_agent_message"] as? String) ?? "Your Codex task is ready for review.")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    events.append(GlintEvent(source: "codex", title: "Codex task finished", detail: String(message.prefix(180)), project: project, projectPath: path, appBundleIdentifier: state.appBundleIdentifier))
                }
            }
            files[url] = state
        }
        files = files.filter { FileManager.default.fileExists(atPath: $0.key.path) }
        return events
    }

    private func discover(primeExisting: Bool) {
        lastDiscovery = Date()
        for searchRoot in discoveryRoots(includeHistory: primeExisting) {
          guard let enumerator = FileManager.default.enumerator(at: searchRoot,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]) else { continue }
          for case let url as URL in enumerator where url.pathExtension == "jsonl" && files[url] == nil {
            let size = ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            var cwd: String?; var appBundleIdentifier: String?
            if let handle = try? FileHandle(forReadingFrom: url), let head = try? handle.read(upToCount: 65_536) {
                try? handle.close()
                if let line = [UInt8](head).split(separator: 0x0a).first,
                   let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                   let payload = object["payload"] as? [String: Any] {
                    cwd = payload["cwd"] as? String
                    appBundleIdentifier = Self.bundleIdentifier(for: payload["originator"] as? String,
                                                                source: payload["source"])
                }
            }
            // Anything present when Glint launches is historical and is tailed from EOF.
            // Files created during this run are read from the start so a very short task
            // cannot finish between discovery passes without being noticed.
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let historical = primeExisting || modified < launchedAt
            files[url] = FileState(offset: historical ? UInt64(size) : 0, cwd: cwd, appBundleIdentifier: appBundleIdentifier)
          }
        }
    }

    private func discoveryRoots(includeHistory: Bool) -> [URL] {
        if includeHistory { return [root] }
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter(); formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy/MM/dd"
        return [Date(), calendar.date(byAdding: .day, value: -1, to: Date())].compactMap { date in
            guard let date else { return nil }
            let candidate = root.appendingPathComponent(formatter.string(from: date), isDirectory: true)
            return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
        }
    }

    static func bundleIdentifier(for originator: String?, source: Any?) -> String? {
        // Codex approval/guardian workers can report `task_complete`, but that
        // only means the hidden permission check finished—not the user's task.
        // Every subagent session is excluded before any of its events are read.
        if let metadata = source as? [String: Any], metadata["subagent"] != nil { return nil }
        let value = (originator ?? "").lowercased()
        if value.contains("codex desktop") { return "com.openai.codex" }
        if value.contains("codex_cli") || value.contains("codex cli") { return "com.apple.Terminal" }
        return nil
    }
}
