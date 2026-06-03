#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
BUILD_ARCHS="${BUILD_ARCHS:-}"
BUNDLE_ID="${BUNDLE_ID:-jp.techguide.macclipy}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DEVELOPMENT_CRASH_MODAL_ENABLED="${DEVELOPMENT_CRASH_MODAL_ENABLED:-0}"
APP_NAME="MacClipy"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_NAME="AppIcon"
ICON_FILE="$ICON_NAME.icns"

SWIFT_BUILD_ARGS=(swift build -c "$BUILD_CONFIG" --package-path "$ROOT_DIR")
BINARY_PATH="$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME"

if [[ -n "$BUILD_ARCHS" ]]; then
  for arch in $BUILD_ARCHS; do
    SWIFT_BUILD_ARGS+=(--arch "$arch")
  done
  BINARY_PATH="$ROOT_DIR/.build/apple/Products/$(tr '[:lower:]' '[:upper:]' <<< "${BUILD_CONFIG:0:1}")${BUILD_CONFIG:1}/$APP_NAME"
fi

if [[ "$DEVELOPMENT_CRASH_MODAL_ENABLED" == "1" ]]; then
  DEVELOPMENT_CRASH_MODAL_PLIST_VALUE="<true/>"
else
  DEVELOPMENT_CRASH_MODAL_PLIST_VALUE="<false/>"
fi

"${SWIFT_BUILD_ARGS[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp -R "$ROOT_DIR/Sources/MacClipy/Resources/"*.lproj "$RESOURCES_DIR/"
cp "$ROOT_DIR/Sources/MacClipy/Resources/$ICON_FILE" "$RESOURCES_DIR/$ICON_FILE"

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
  <key>CFBundleIconFile</key>
  <string>${ICON_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MacClipy</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
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

codesign --force --deep --sign - "$APP_DIR"

echo "Created $APP_DIR"
