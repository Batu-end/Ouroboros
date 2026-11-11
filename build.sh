#!/bin/bash
# Builds Ouroboros.app — a self-contained, Dock-less menu bar app bundle.
#   ./build.sh          build only
#   ./build.sh --run    build, then relaunch it
set -euo pipefail

cd "$(dirname "$0")"

APP="Ouroboros.app"
CONTENTS="$APP/Contents"

echo "▸ compiling (release)…"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/Ouroboros"
[ -x "$BIN" ] || { echo "✗ binary not found at $BIN"; exit 1; }

echo "▸ assembling $APP…"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Ouroboros"
cp Resources/Info.plist "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

# Ad-hoc signature: enough for local use and for notification registration.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (ad-hoc signing skipped)"

echo "✓ built $(pwd)/$APP"

if [ "${1:-}" = "--run" ]; then
  pkill -x Ouroboros 2>/dev/null || true
  sleep 0.3
  open "$APP"
  echo "✓ running — look at the right side of your menu bar"
fi
