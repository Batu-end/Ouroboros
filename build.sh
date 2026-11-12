#!/bin/bash
# Builds Ouroboros.app — a self-contained, Dock-less menu bar app bundle.
#   ./build.sh            build for this Mac
#   ./build.sh --run      build, then relaunch it
#   ./build.sh --release  universal (Apple silicon + Intel) build, zipped into dist/
set -euo pipefail

cd "$(dirname "$0")"

APP="Ouroboros.app"
CONTENTS="$APP/Contents"
MODE="${1:-}"

ARCH_FLAGS=()
if [ "$MODE" = "--release" ]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
  echo "▸ compiling (release, universal)…"
else
  echo "▸ compiling (release)…"
fi

swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}

BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Ouroboros"
[ -x "$BIN" ] || { echo "✗ binary not found at $BIN"; exit 1; }

echo "▸ assembling $APP…"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Ouroboros"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
printf 'APPL????' > "$CONTENTS/PkgInfo"

# Ad-hoc signature: enough for local use and for notification registration.
# It is not a Developer ID signature, so downloaded copies still need Open Anyway.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (ad-hoc signing skipped)"

echo "✓ built $(pwd)/$APP  [$(lipo -archs "$CONTENTS/MacOS/Ouroboros")]"

if [ "$MODE" = "--release" ]; then
  VERSION="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
  mkdir -p dist
  ZIP="dist/Ouroboros-$VERSION.zip"
  rm -f "$ZIP"
  # ditto keeps the bundle's metadata intact, which a plain `zip` does not.
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "✓ packaged $(pwd)/$ZIP ($(du -h "$ZIP" | cut -f1))"
fi

if [ "$MODE" = "--run" ]; then
  pkill -x Ouroboros 2>/dev/null || true
  sleep 0.3
  open "$APP"
  echo "✓ running — look at the right side of your menu bar"
fi
