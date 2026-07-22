import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = PanelController()
    private let codexDesktop = CodexDesktopWatcher()
    private var timer: Timer?
    private var statusItem: NSStatusItem?
    private var doneOnlyItem: NSMenuItem?
    private var stepsItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        try? GlintPaths.prepare()
        makeMenu()
        timer = Timer.scheduledTimer(timeInterval: 0.55, target: self,
                                     selector: #selector(timerFired), userInfo: nil, repeats: true)
    }

    private func makeMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Glint")
        let menu = NSMenu()
        let updates = NSMenuItem(title: "Notification mode", action: nil, keyEquivalent: "")
        let updatesMenu = NSMenu(title: "Notification mode")
        let done = NSMenuItem(title: "Done only", action: #selector(useDoneOnly), keyEquivalent: "")
        let steps = NSMenuItem(title: "Step updates", action: #selector(useSteps), keyEquivalent: "")
        done.target = self; steps.target = self; updatesMenu.addItem(done); updatesMenu.addItem(steps)
        updates.submenu = updatesMenu; menu.addItem(updates); doneOnlyItem = done; stepsItem = steps
        menu.addItem(withTitle: "Reload settings", action: #selector(reload), keyEquivalent: "r")
        menu.addItem(.separator()); menu.addItem(withTitle: "Quit Glint", action: #selector(quit), keyEquivalent: "q")
        menu.items.filter { $0.action != nil }.forEach { $0.target = self }
        item.menu = menu; statusItem = item; updateModeChecks()
    }
    @objc private func reload() { panel.config = ConfigStore.load(); updateModeChecks() }
    @objc private func useDoneOnly() { setMode("doneOnly") }
    @objc private func useSteps() { setMode("steps") }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func timerFired() { poll() }

    private func setMode(_ mode: String) {
        panel.config.notificationMode = mode
        try? ConfigStore.save(panel.config)
        updateModeChecks()
    }

    private func updateModeChecks() {
        doneOnlyItem?.state = panel.config.notificationMode == "steps" ? .off : .on
        stepsItem?.state = panel.config.notificationMode == "steps" ? .on : .off
    }

    private func poll() {
        for event in codexDesktop.poll(notificationMode: panel.config.notificationMode) {
            handle(event)
        }
        for event in EventQueue.drain() {
            handle(event)
        }
    }

    private func handle(_ event: GlintEvent) {
        guard NotificationPolicy.shouldDisplay(event, mode: panel.config.notificationMode) else { return }
        if event.status == "dismiss" { panel.hide() } else { panel.show(event) }
    }
}

@main enum GlintMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "notify" || args.first == "hook" {
            let source = args.count > 1 ? args[1] : "codex"
            let input = FileHandle.standardInput.readDataToEndOfFile()
            do { try EventQueue.push(HookParser.event(source: source, input: input, arguments: Array(args.dropFirst(2)))) }
            catch { FileHandle.standardError.write(Data("glint: \(error)\n".utf8)); exit(1) }
            return
        }
        if args.first == "dismiss" {
            try? EventQueue.push(GlintEvent(source: "system", title: "Dismiss", detail: "New prompt started", status: "dismiss")); return
        }
        if args.first == "config" {
            if !FileManager.default.fileExists(atPath: GlintPaths.config.path) { try? ConfigStore.save(GlintConfig()) }
            print(GlintPaths.config.path); return
        }
        if args.first == "help" || args.first == "--help" {
            print("Glint — ambient completion notifications\n\n  glint                 run the menu-bar watcher\n  glint dismiss         fade the current notification\n  glint hook <source>   receive JSON hook input\n  glint config          create and print the config path")
            return
        }
        let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.run()
    }
}
