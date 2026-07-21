#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP=${GLINT_APP:-"$HOME/Applications/Glint.app"}
BIN="$APP/Contents/MacOS/glint"
FANOUT="$APP/Contents/Resources/codex-notify-fanout.sh"
AGENT="$HOME/Library/LaunchAgents/dev.glint.agent-notifications.plist"
MERGER="$ROOT/scripts/merge-hooks.js"

if [ -f "$HOME/.codex/hooks.json" ]; then
  /usr/bin/osascript -l JavaScript "$MERGER" remove-codex "$HOME/.codex/hooks.json" "$BIN dismiss"
fi
if [ -f "$HOME/.claude/settings.json" ]; then
  /usr/bin/osascript -l JavaScript "$MERGER" remove-claude "$HOME/.claude/settings.json" "$BIN hook claude" "$BIN dismiss"
fi
if [ -f "$HOME/.codex/config.toml" ]; then
  awk -v bin="$BIN" -v fanout="$FANOUT" '
    index($0, "notify = [\"" bin "\", \"hook\", \"codex\"]") == 0 &&
    index($0, "notify = [\"" fanout "\"]") == 0 { print }
  ' "$HOME/.codex/config.toml" > "$HOME/.codex/config.toml.glint-tmp"
  mv "$HOME/.codex/config.toml.glint-tmp" "$HOME/.codex/config.toml"
fi
launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
rm -f "$AGENT"
if [ -d "$APP" ]; then mv "$APP" "$HOME/.Trash/Glint-$(date +%Y%m%d-%H%M%S).app"; fi
printf 'Uninstalled Glint. Local history/settings remain in ~/Library/Application Support/Glint.\n'
