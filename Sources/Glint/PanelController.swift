import AppKit
import SwiftUI

@MainActor final class PanelController {
    private var panel: NSPanel?
    private var closeWork: DispatchWorkItem?
    private var activationObserver: NSObjectProtocol?
    private var shownAt = Date.distantPast
    private var originBundleIdentifier: String?
    var config = ConfigStore.load()

    func show(_ event: GlintEvent) {
        let mouse = NSEvent.mouseLocation
        guard config.enabled,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main ?? NSScreen.screens.first
        else { return }
        panel?.orderOut(nil); closeWork?.cancel()
        let size = NSSize(width: 406, height: 180)
        let visible = screen.visibleFrame
        let left = config.position.contains("left")
        let bottom = config.position.contains("bottom")
        let edgeInset: CGFloat = 30
        let topInset: CGFloat = 22
        let finalX = left ? visible.minX + edgeInset : visible.maxX - size.width - edgeInset
        let finalY = bottom ? visible.minY + edgeInset : visible.maxY - size.height - topInset
        let startX = finalX + (left ? -28 : 28)

        let panel = NSPanel(contentRect: NSRect(x: startX, y: finalY, width: size.width, height: size.height),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.alphaValue = 0
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ToastView(event: event, theme: config.theme) { [weak self] in self?.hide() })
        panel.orderFrontRegardless(); self.panel = panel
        shownAt = Date()
        originBundleIdentifier = event.resolvedBundleIdentifier
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      Date().timeIntervalSince(self.shownAt) > 0.75,
                      let expected = self.originBundleIdentifier,
                      let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      activated.bundleIdentifier == expected
                else { return }
                self.hide()
            }
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.12 : 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrameOrigin(NSPoint(x: finalX, y: finalY))
                panel.animator().alphaValue = 1
            }
        }
        if config.sound.lowercased() != "none" { NSSound(named: NSSound.Name(config.sound))?.play() }
        if config.duration > 0 {
            let work = DispatchWorkItem { [weak self] in self?.hide() }; closeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + config.duration, execute: work)
        }
    }

    func hide() {
        guard let panel, let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        let left = config.position.contains("left")
        let targetX = left ? screen.visibleFrame.minX - panel.frame.width - 30 : screen.visibleFrame.maxX + 30
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.12 : 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            if !reduceMotion { panel.animator().setFrameOrigin(NSPoint(x: targetX, y: panel.frame.minY)) }
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }
}

struct ToastView: View {
    let event: GlintEvent; let theme: String; let close: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var brand: AgentBrand { AgentBrand(source: event.source) }
    private var accent: Color { theme == "mono" ? .white : brand.color }
    private var failed: Bool { event.status == "failure" || event.status == "error" }
    private var statusLabel: String { failed ? "FAILED" : event.status == "cancelled" ? "CANCELLED" : "COMPLETE" }
    var body: some View {
        ZStack {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 18).fill(Color(nsColor: .windowBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.42))
            }
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(contrast == .increased ? 0.38 : 0.16), lineWidth: contrast == .increased ? 1.5 : 1)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(failed ? Color.red : accent)
                        .accessibilityHidden(true)
                    Text(brand.name).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(.secondary)
                    Text("/ \(statusLabel)").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(failed ? Color.red : accent.opacity(0.9))
                    Spacer()
                    Text(event.createdAt, style: .time).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss notification")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.system(size: 16, weight: .semibold, design: .rounded))
                    if let project = event.project { Text(project).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(accent) }
                    Text(event.detail).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack(spacing: 8) {
                    ActionButton(label: "Open chat", icon: "arrow.up.forward.app") {
                        activateOrigin(); close()
                    }
                    Menu {
                        Button("Copy output", systemImage: "doc.on.doc") {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(event.detail, forType: .string)
                        }
                        if let path = event.projectPath {
                            Button("Open project", systemImage: "folder") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: path)); close()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 28)
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .accessibilityLabel("More notification actions")
                    Spacer()
                }
            }.padding(.horizontal, 16).padding(.vertical, 13)
        }
        .padding(1).frame(width: 392, height: 166)
        .scaleEffect(hovering && !reduceMotion ? 1.008 : 1)
        .offset(y: hovering && !reduceMotion ? -1 : 0)
        .shadow(color: .black.opacity(hovering ? 0.38 : 0.28), radius: hovering ? 17 : 13, y: hovering ? 8 : 6)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: hovering)
        .frame(width: 406, height: 180)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(brand.name) \(statusLabel.lowercased()) notification")
    }

    private func activateOrigin() {
        let identifier = event.resolvedBundleIdentifier
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first {
            app.activate(options: [.activateAllWindows])
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

private extension GlintEvent {
    var resolvedBundleIdentifier: String {
        if let appBundleIdentifier { return appBundleIdentifier }
        let sourceName = source.lowercased()
        return sourceName.contains("claude") || sourceName.contains("anthropic") ? "com.apple.Terminal" : "com.openai.codex"
    }
}

private struct AgentBrand {
    let name: String
    let color: Color

    init(source raw: String) {
        let source = raw.lowercased()
        switch source {
        case let value where value.contains("claude") || value.contains("anthropic"):
            (name, color) = ("CLAUDE CODE", Color(red: 0.85, green: 0.38, blue: 0.22))
        case let value where value.contains("codex") || value.contains("openai") || value == "gpt" || value.contains("chatgpt"):
            (name, color) = ("OPENAI CODEX", Color(red: 0.06, green: 0.64, blue: 0.50))
        case let value where value.contains("cursor"):
            (name, color) = ("CURSOR", Color(red: 0.56, green: 0.52, blue: 0.96))
        case let value where value.contains("copilot") || value.contains("github"):
            (name, color) = ("GITHUB COPILOT", Color(red: 0.58, green: 0.39, blue: 0.95))
        case let value where value.contains("gemini"):
            (name, color) = ("GEMINI CLI", Color(red: 0.28, green: 0.56, blue: 0.98))
        case let value where value.contains("windsurf") || value.contains("codeium"):
            (name, color) = ("WINDSURF", Color(red: 0.05, green: 0.78, blue: 0.69))
        case let value where value.contains("aider"):
            (name, color) = ("AIDER", Color(red: 0.25, green: 0.78, blue: 0.45))
        case let value where value.contains("cline"):
            (name, color) = ("CLINE", Color(red: 0.31, green: 0.49, blue: 0.96))
        case let value where value.contains("continue"):
            (name, color) = ("CONTINUE", Color(red: 0.96, green: 0.63, blue: 0.20))
        case let value where value.contains("amazon") || value == "q" || value.contains("amazon-q"):
            (name, color) = ("AMAZON Q", Color(red: 0.55, green: 0.37, blue: 0.92))
        case let value where value.contains("devin"):
            (name, color) = ("DEVIN", Color(red: 0.36, green: 0.42, blue: 0.82))
        case let value where value.contains("kiro"):
            (name, color) = ("KIRO", Color(red: 0.66, green: 0.39, blue: 0.91))
        case let value where value.contains("replit"):
            (name, color) = ("REPLIT AGENT", Color(red: 0.95, green: 0.38, blue: 0.06))
        case let value where value.contains("qwen"):
            (name, color) = ("QWEN CODE", Color(red: 0.45, green: 0.30, blue: 0.88))
        default:
            (name, color) = (raw.uppercased(), Color(red: 0.68, green: 0.72, blue: 0.76))
        }
    }
}

private struct ActionButton: View {
    let label: String; let icon: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon).font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
