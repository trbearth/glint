# Glint Beta Release

Glint is an open-source macOS background utility for AI coding agents. It stays out of the way while work is running, then displays a native glass notification when Codex or Claude Code finishes.

## Highlights

- Native macOS menu-bar app with no Electron runtime
- Codex CLI, Codex Desktop, and Claude Code integration
- Completion-only notifications by default, with optional step updates
- Agent-specific visual identities, sound, theme, and position
- One-click return to the originating app or project
- Local-only operation with no accounts, analytics, or cloud service
- Safe hook merging, launch at login, and duplicate-event protection

## Install

1. Download `Glint-macOS.zip` and unzip it.
2. Open Terminal in the unzipped `Glint-release` folder.
3. Run `chmod +x scripts/*.sh scripts/glint-run`.
4. Run `./scripts/install.sh`.
5. If macOS blocks the unsigned beta, use **System Settings → Privacy & Security → Open Anyway**.
6. In Codex, run `/hooks` once to review and trust Glint's prompt hook.

No Xcode is required for release users. macOS 13 or newer is recommended.

## Beta note

This build is ad-hoc signed but not yet Apple-notarized. The source is public and all processing remains on the user's Mac. Please report bugs through GitHub Issues.
