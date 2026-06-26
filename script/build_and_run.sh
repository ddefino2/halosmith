#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Halosmith"
APP_VERSION="0.2.3"
BUNDLE_ID="com.halosmith.Halosmith"
MIN_SYSTEM_VERSION="14.0"
COMPATIBLE_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
BUILD_PATH="/tmp/halosmith-swift-build"
ICON_SOURCE="$ROOT_DIR/halosmith-icon.jpg"
ICONSET_DIR="$BUILD_PATH/Halosmith.iconset"
ICON_FILE="$BUILD_PATH/Halosmith.icns"

# The installed macOS 26.2 SDK is newer than this machine's Command Line Tools
# compiler build. Pin the compatible installed SDK until Apple updates the pair.
if [[ -d "$COMPATIBLE_SDK" ]]; then
  export SDKROOT="$COMPATIBLE_SDK"
fi
export CLANG_MODULE_CACHE_PATH="/tmp/halosmith-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="/tmp/halosmith-swiftpm-cache"
SWIFT_BUILD_ARGS=(--disable-sandbox --build-path "$BUILD_PATH")

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build "${SWIFT_BUILD_ARGS[@]}"
BUILD_BINARY="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
while read -r filename size; do
  sips -s format png -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
done <<'SIZES'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
SIZES
iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ROOT_DIR/halosmith-logo-hologram.png" "$APP_RESOURCES/halosmith-logo-hologram.png"
cp "$ICON_FILE" "$APP_RESOURCES/Halosmith.icns"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME v$APP_VERSION</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$APP_VERSION</string>
  <key>CFBundleIconFile</key><string>Halosmith.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

open_app() { /usr/bin/open -n "$APP_BUNDLE"; }

case "$MODE" in
  run) open_app ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) open_app; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
