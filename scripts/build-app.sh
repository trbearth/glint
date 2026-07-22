#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
APP="$ROOT/Glint.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -swift-version 5 -O -whole-module-optimization -parse-as-library \
  "$ROOT"/Sources/Glint/*.swift \
  -o "$APP/Contents/MacOS/glint" \
  -framework AppKit -framework SwiftUI
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/scripts/glint-run" "$APP/Contents/Resources/glint-run"
chmod +x "$APP/Contents/Resources/glint-run"
printf 'Built %s\n' "$APP"
