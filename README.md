# Glint ✦

Glint is a tiny, open-source macOS menu-bar app that tells you when an AI coding agent is done. A native glass panel slides in, plays an optional sound, and links back to your work. There are no accounts, analytics, cloud services, or Electron runtime.

Codex CLI, Codex Desktop, and Claude Code are the first-party integrations today. Glint also provides a generic process wrapper and branded identities for other tools; a branded identity is not a claim of native integration.

## Install a release (recommended)

Regular users do **not** need Xcode. Download `Glint-macOS.zip` from the latest GitHub Release, unzip it, then open Terminal in the unzipped folder and run:

```sh
chmod +x scripts/*.sh scripts/glint-run
./scripts/install.sh
```

This copies Glint to `~/Applications`, starts it at login, and safely adds hooks for installed agents. Glint reads Codex's local session log for the real `task_complete` event; it does not use Codex's broader turn-ended callback. Existing non-Glint callbacks are preserved. In Codex, run `/hooks` once to review and trust the prompt-dismissal hook.

Because the beta is not yet notarized, macOS may block the first launch. Open **System Settings → Privacy & Security**, find the Glint message, and choose **Open Anyway**. You only need to do this once.

Requirements: macOS 13 or newer, plus Codex and/or Claude Code. Public releases should be signed and notarized.

## Build from source

Building requires Xcode or Xcode Command Line Tools.

```sh
git clone <your-fork-or-repository-url>
cd glint
chmod +x scripts/*.sh scripts/glint-run
./scripts/build-app.sh
./scripts/install.sh
```

For development, `swift run glint` runs the watcher.

## Integrations

For Codex CLI and Codex Desktop, Glint tails the local session log and displays a card only after `task_complete`. This avoids false completions when a turn is interrupted. A prompt-submission hook dismisses the previous card; unrelated personal hooks and callbacks are preserved.

For Claude Code, the installer merges a `Stop` completion hook and `UserPromptSubmit` dismissal hook without replacing unrelated hooks. It also adds a Codex prompt-dismissal hook. Timestamped backups are created before JSON hook files are changed.

Where native hooks are unavailable, wrap a process while preserving its exit code:

```sh
GLINT_BIN="$HOME/Applications/Glint.app/Contents/MacOS/glint" scripts/glint-run your-agent command args
```

Glint recognizes visual identities for Codex/OpenAI, Claude Code, Cursor, GitHub Copilot, Gemini CLI, Windsurf, Aider, Cline, Continue, Amazon Q, Devin, Kiro, Replit Agent, and Qwen Code. Unknown sources use a neutral identity.

## Configure and test

Run `~/Applications/Glint.app/Contents/MacOS/glint config`, edit the printed JSON file, then choose **Reload settings** from the sparkle menu.

```json
{
  "duration": 0,
  "enabled": true,
  "position": "top-right",
  "sound": "Glass",
  "theme": "brand",
  "notificationMode": "doneOnly"
}
```

Positions: `top-right`, `top-left`, `bottom-right`, `bottom-left`. Themes: `brand` and `mono` (`ember` and `terminal` remain accepted legacy aliases). Duration `0` stays visible until dismissed. Set sound to `none` or a macOS sound name. Choose **Done only** (the default) or **Step updates** directly from the sparkle menu; the latter surfaces supported Codex progress messages while work is running.

Completion cards dismiss when you open their chat/project, switch back to work, or submit another prompt. **Open chat** currently activates the originating application or terminal; exact conversation deep links depend on support from each agent.

## Architecture and portability

```text
Codex notify/desktop ─┐
Claude Stop ─────────┼─> adapter ─> private atomic inbox ─> native glass panel
process exit ────────┘
```

The adapter protocol is plain JSON so future Windows and Linux frontends can consume the same event shape. The current UI is native AppKit/SwiftUI.

## Why I built Glint

AI coding agents make it possible to hand off longer tasks, but they also create a new problem: you either keep checking the terminal or miss the moment the work finishes. I built Glint to make that workflow feel native to the desktop—quiet while an agent is working, useful the instant it is done, and one click away from the original chat.

Glint began as a small notification experiment and grew through real use: duplicate-event protection, agent-specific visual identities, completion-only and step-update modes, accessible motion and contrast behavior, private local event handling, and safe hook installation. It is also structured so Windows and Linux frontends can be added without redesigning the event pipeline.

## Privacy

Everything stays local. Settings and a private atomic event inbox live under `~/Library/Application Support/Glint`. Event files use user-only permissions and are deleted immediately after display; stale claimed records are removed after seven days. Events may briefly contain a project path and short assistant-output excerpt. Nothing is sent to a server and local files are not independently encrypted. Quit Glint and delete that directory to clear all Glint data.

## Update and uninstall

Run a newer release's `scripts/install.sh` to update while keeping settings. To remove hooks, launch-at-login registration, and the app:

```sh
./scripts/uninstall.sh
```

Uninstall moves the app to Trash and deliberately leaves local data in Application Support until you delete it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Good next steps include a full settings window, automatic updates, signed/notarized releases, exact per-agent chat deep links, and Windows/Linux tray frontends.

MIT licensed.
