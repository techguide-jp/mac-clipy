#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
DEVELOPMENT_CRASH_MODAL_ENABLED="${DEVELOPMENT_CRASH_MODAL_ENABLED:-0}"
APP_NAME="MacClipy"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [[ "$DEVELOPMENT_CRASH_MODAL_ENABLED" == "1" ]]; then
  DEVELOPMENT_CRASH_MODAL_PLIST_VALUE="<true/>"
else
  DEVELOPMENT_CRASH_MODAL_PLIST_VALUE="<false/>"
fi

swift build -c "$BUILD_CONFIG" --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp -R "$ROOT_DIR/Sources/MacClipy/Resources/"*.lproj "$RESOURCES_DIR/"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>ja</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>ja</string>
    <string>en</string>
  </array>
  <key>CFBundleExecutable</key>
  <string>MacClipy</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.MacClipy</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MacClipy</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>MacClipyDevelopmentCrashModalEnabled</key>
  ${DEVELOPMENT_CRASH_MODAL_PLIST_VALUE}
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Created $APP_DIR"
