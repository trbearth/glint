#!/bin/sh
set -eu

APP=${GLINT_APP:-"$HOME/Applications/Glint.app"}
BIN="$APP/Contents/MacOS/glint"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MERGER="$ROOT/scripts/merge-hooks.js"
STAMP=$(date +%Y%m%d-%H%M%S)

[ -x "$BIN" ] || { printf 'Glint is not installed at %s\n' "$APP" >&2; exit 1; }
[ -f "$MERGER" ] || { printf 'Missing hook merger: %s\n' "$MERGER" >&2; exit 1; }

mkdir -p "$HOME/.codex" "$HOME/.claude"
CODEX_CONFIG="$HOME/.codex/config.toml"
[ -f "$CODEX_CONFIG" ] || : > "$CODEX_CONFIG"

if grep -Eq '^[[:space:]]*notify[[:space:]]*=.*(Glint\.app|codex-notify-fanout\.sh)' "$CODEX_CONFIG"; then
  cp "$CODEX_CONFIG" "$CODEX_CONFIG.glint-backup-$STAMP"
  awk '!(/^[[:space:]]*notify[[:space:]]*=/ && ($0 ~ /Glint\.app/ || $0 ~ /codex-notify-fanout\.sh/)) { print }' "$CODEX_CONFIG" > "$CODEX_CONFIG.glint-tmp"
  mv "$CODEX_CONFIG.glint-tmp" "$CODEX_CONFIG"
  printf 'Removed the legacy Codex callback; Glint now waits for the real task-complete event.\n'
fi

CODEX_HOOKS="$HOME/.codex/hooks.json"
CLAUDE_CONFIG="$HOME/.claude/settings.json"
[ -f "$CODEX_HOOKS" ] || printf '{"description":"Personal Codex hooks","hooks":{}}\n' > "$CODEX_HOOKS"
[ -f "$CLAUDE_CONFIG" ] || printf '{"hooks":{}}\n' > "$CLAUDE_CONFIG"
cp "$CODEX_HOOKS" "$CODEX_HOOKS.glint-backup-$STAMP"
cp "$CLAUDE_CONFIG" "$CLAUDE_CONFIG.glint-backup-$STAMP"

/usr/bin/osascript -l JavaScript "$MERGER" add-codex "$CODEX_HOOKS" "$BIN dismiss"
/usr/bin/osascript -l JavaScript "$MERGER" add-claude "$CLAUDE_CONFIG" "$BIN hook claude" "$BIN dismiss"
printf 'Connected prompt dismissal and Claude Code completion hooks. Backups end in %s.\n' "$STAMP"
printf 'In Codex, run /hooks once to review and trust the Glint hook.\n'
