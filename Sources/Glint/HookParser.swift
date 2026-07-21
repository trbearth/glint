import Foundation

enum HookParser {
    static func event(source: String, input: Data, arguments: [String]) -> GlintEvent {
        var object: [String: Any] = [:]
        if let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any] { object = json }
        if object.isEmpty, let first = arguments.first, let data = first.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { object = json }

        let cwd = (object["cwd"] as? String) ?? FileManager.default.currentDirectoryPath
        let project = URL(fileURLWithPath: cwd).lastPathComponent
        let transcript = object["last_assistant_message"] as? String
        let reason = object["reason"] as? String
        let status = ((object["exit_code"] as? Int) ?? 0) == 0 ? "success" : "failure"
        let name = source.lowercased() == "claude" ? "Claude Code" : "Codex"
        let detail = transcript?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(150).description
            ?? reason ?? "Your agent is ready for you."
        let terminal = ProcessInfo.processInfo.environment["TERM_PROGRAM"]
        let bundleID = terminal == "Apple_Terminal" ? "com.apple.Terminal" : terminal == "iTerm.app" ? "com.googlecode.iterm2" : nil
        return GlintEvent(source: source.lowercased(), title: "\(name) finished", detail: detail, status: status, project: project, projectPath: cwd, appBundleIdentifier: bundleID)
    }
}
