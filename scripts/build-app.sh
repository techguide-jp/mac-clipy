#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
BUILD_ARCHS="${BUILD_ARCHS:-}"
BUNDLE_ID="${BUNDLE_ID:-jp.techguide.macclipy}"
BUNDLE_DISPLAY_NAME="${BUNDLE_DISPLAY_NAME:-MacClipy}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DEVELOPMENT_CRASH_MODAL_ENABLED="${DEVELOPMENT_CRASH_MODAL_ENABLED:-0}"
ANALYTICS_ENABLED="${ANALYTICS_ENABLED:-0}"
ANALYTICS_ENDPOINT="${ANALYTICS_ENDPOINT:-https://techguide.jp/api/macclipy/analytics}"
SIGNING_MODE="${SIGNING_MODE:-adhoc}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-${DEVELOPER_ID_APPLICATION:-}}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/techguide-jp/mac-clipy/releases/latest/download/appcast.xml}"
DEFAULT_SPARKLE_PUBLIC_ED_KEY="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-$DEFAULT_SPARKLE_PUBLIC_ED_KEY}"
APP_NAME="MacClipy"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ICON_NAME="AppIcon"
ICON_FILE="$ICON_NAME.icns"

SWIFT_BUILD_ARGS=(swift build -c "$BUILD_CONFIG" --package-path "$ROOT_DIR")
SWIFT_BUILD_ARGS+=(-Xlinker -rpath -Xlinker "@executable_path/../Frameworks")
BINARY_PATH="$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME"

if [[ "$SIGNING_MODE" != "adhoc" && "$SIGNING_MODE" != "developer-id" ]]; then
  echo "SIGNING_MODE must be adhoc or developer-id." >&2
  exit 1
fi

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
  if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
    echo "CODE_SIGN_IDENTITY or DEVELOPER_ID_APPLICATION is required for Developer ID signing." >&2
    exit 1
  fi
  if [[ "$SPARKLE_PUBLIC_ED_KEY" == "$DEFAULT_SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "SPARKLE_PUBLIC_ED_KEY is required for Developer ID distribution." >&2
    exit 1
  fi
fi

if [[ "$ANALYTICS_ENABLED" != "0" && "$ANALYTICS_ENABLED" != "1" ]]; then
  echo "ANALYTICS_ENABLED must be 0 or 1." >&2
  exit 1
fi

if [[ "$ANALYTICS_ENABLED" == "1" && "$SIGNING_MODE" != "developer-id" ]]; then
  echo "Anonymous analytics can only be enabled for Developer ID builds." >&2
  exit 1
fi

if [[ -n "$BUILD_ARCHS" ]]; then
  for arch in $BUILD_ARCHS; do
    SWIFT_BUILD_ARGS+=(--arch "$arch")
  done
  BINARY_PATH="$ROOT_DIR/.build/apple/Products/$(tr '[:lower:]' '[:upper:]' <<< "${BUILD_CONFIG:0:1}")${BUILD_CONFIG:1}/$APP_NAME"
fi
BUILD_PRODUCTS_DIR="$(dirname "$BINARY_PATH")"

if [[ "$DEVELOPMENT_CRASH_MODAL_ENABLED" == "1" ]]; then
  DEVELOPMENT_CRASH_MODAL_PLIST_VALUE="<true/>"
else
  DEVELOPMENT_CRASH_MODAL_PLIST_VALUE="<false/>"
fi

if [[ "$ANALYTICS_ENABLED" == "1" ]]; then
  ANALYTICS_ENABLED_PLIST_VALUE="<true/>"
else
  ANALYTICS_ENABLED_PLIST_VALUE="<false/>"
fi

"${SWIFT_BUILD_ARGS[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp -R "$ROOT_DIR/Sources/MacClipy/Resources/"*.lproj "$RESOURCES_DIR/"
cp "$ROOT_DIR/Sources/MacClipy/Resources/$ICON_FILE" "$RESOURCES_DIR/$ICON_FILE"
cp "$ROOT_DIR/Sources/MacClipy/Resources/PrivacyInfo.xcprivacy" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
for resource_bundle in "$BUILD_PRODUCTS_DIR"/*.bundle; do
  [[ -d "$resource_bundle" ]] || continue
  ditto "$resource_bundle" "$RESOURCES_DIR/$(basename "$resource_bundle")"
done

SPARKLE_FRAMEWORK="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK="$(
    find "$ROOT_DIR/.build/artifacts" -path "*/Sparkle.framework" -type d -print 2>/dev/null | head -n 1 || true
  )"
fi
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found under .build. Run swift package resolve/build first." >&2
  exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"

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
  <key>CFBundleDisplayName</key>
  <string>${BUNDLE_DISPLAY_NAME}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${BUNDLE_DISPLAY_NAME}</string>
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
  <key>MacClipyAnalyticsEnabled</key>
  ${ANALYTICS_ENABLED_PLIST_VALUE}
  <key>MacClipyAnalyticsEndpoint</key>
  <string>${ANALYTICS_ENDPOINT}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUFeedURL</key>
  <string>${SPARKLE_FEED_URL}</string>
  <key>SUPublicEDKey</key>
  <string>${SPARKLE_PUBLIC_ED_KEY}</string>
  <key>SUAutomaticallyUpdate</key>
  <false/>
  <key>SUVerifyUpdateBeforeExtraction</key>
  <true/>
</dict>
</plist>
PLIST

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Created $APP_DIR"
