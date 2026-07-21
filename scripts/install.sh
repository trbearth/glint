#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$ROOT/Glint.app"
DEST=${GLINT_APP:-"$HOME/Applications/Glint.app"}
AGENT="$HOME/Library/LaunchAgents/dev.glint.agent-notifications.plist"

[ -d "$SOURCE" ] || { printf 'Glint.app is missing. Build it or download a release first.\n' >&2; exit 1; }
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
if [ -d "$DEST" ]; then mv "$DEST" "$DEST.previous-$(date +%Y%m%d-%H%M%S)"; fi
cp -R "$SOURCE" "$DEST"

cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>dev.glint.agent-notifications</string>
<key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/glint</string></array>
<key>RunAtLoad</key><true/>
</dict></plist>
EOF
plutil -lint "$AGENT" >/dev/null
launchctl bootstrap "gui/$(id -u)" "$AGENT"
GLINT_APP="$DEST" "$ROOT/scripts/install-hooks.sh"
printf 'Installed Glint at %s and enabled launch at login.\n' "$DEST"
