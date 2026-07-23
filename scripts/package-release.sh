#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="MacClipy"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_ID="jp.techguide.macclipy"
BUNDLE_DISPLAY_NAME="MacClipy"
BUILD_ARCHS="x86_64 arm64"
SIGNING_MODE="${SIGNING_MODE:-adhoc}"
ANALYTICS_ENABLED=0
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
STAGING_DIR="$DIST_DIR/dmg-staging"
MOUNT_DIR=""
DMG_NAME="$APP_NAME-v$APP_VERSION.dmg"
CHECKSUM_NAME="$DMG_NAME.sha256"
VOLUME_NAME="$APP_NAME $APP_VERSION"
RW_DMG_NAME="$APP_NAME-v$APP_VERSION-rw.dmg"
BACKGROUND_DIR_NAME=".background"
BACKGROUND_FILE_NAME="background.png"

if [[ "$SIGNING_MODE" != "adhoc" && "$SIGNING_MODE" != "developer-id" ]]; then
  echo "SIGNING_MODE must be adhoc or developer-id." >&2
  exit 1
fi

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required when SIGNING_MODE=developer-id." >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "$MOUNT_DIR" ]] && mount | grep -F -q "on $MOUNT_DIR "; then
    hdiutil detach "$MOUNT_DIR" >/dev/null || true
  fi
  rm -rf "$STAGING_DIR" "$RELEASE_DIR/$RW_DMG_NAME"
}

trap cleanup EXIT

if [[ "$APP_VERSION" == v* ]]; then
  echo "APP_VERSION should not include the leading v. Use APP_VERSION=${APP_VERSION#v}." >&2
  exit 1
fi

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
  ANALYTICS_ENABLED=1
  require_env "DEVELOPER_ID_APPLICATION"
  require_env "APPLE_ID"
  require_env "APPLE_TEAM_ID"
  require_env "APPLE_APP_SPECIFIC_PASSWORD"
  require_env "SPARKLE_PUBLIC_ED_KEY"
fi

echo "==> Checks and app bundle"
BUNDLE_ID="$BUNDLE_ID" \
  BUNDLE_DISPLAY_NAME="$BUNDLE_DISPLAY_NAME" \
  APP_VERSION="$APP_VERSION" \
  BUILD_NUMBER="$BUILD_NUMBER" \
  BUILD_ARCHS="$BUILD_ARCHS" \
  BUILD_CONFIG=release \
  DEVELOPMENT_CRASH_MODAL_ENABLED=0 \
  ANALYTICS_ENABLED="$ANALYTICS_ENABLED" \
  SIGNING_MODE="$SIGNING_MODE" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-${DEVELOPER_ID_APPLICATION:-}}" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}" \
  scripts/check.sh

echo "==> DMG staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/$BACKGROUND_DIR_NAME" "$RELEASE_DIR"
cp -R "$DIST_DIR/$APP_NAME.app" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$ROOT_DIR/Sources/MacClipy/Resources/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
scripts/generate-dmg-background.swift "$STAGING_DIR/$BACKGROUND_DIR_NAME/$BACKGROUND_FILE_NAME"

echo "==> DMG"
rm -f "$RELEASE_DIR/$DMG_NAME" "$RELEASE_DIR/$CHECKSUM_NAME" "$RELEASE_DIR/$RW_DMG_NAME"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDRW \
  "$RELEASE_DIR/$RW_DMG_NAME"

ATTACH_OUTPUT="$(hdiutil attach \
  "$RELEASE_DIR/$RW_DMG_NAME" \
  -readwrite \
  -noverify \
  -noautoopen)"
printf "%s\n" "$ATTACH_OUTPUT"
MOUNT_DIR="$(printf "%s\n" "$ATTACH_OUTPUT" | awk '/\/Volumes\// {for (i = 3; i <= NF; i++) printf "%s%s", (i == 3 ? "" : " "), $i; print ""; exit}')"

if [[ -z "$MOUNT_DIR" ]]; then
  echo "Could not determine mounted DMG path." >&2
  exit 1
fi

if command -v SetFile >/dev/null 2>&1; then
  SetFile -a V "$MOUNT_DIR/$BACKGROUND_DIR_NAME"
  SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_DIR"
fi

echo "==> Finder layout"
osascript <<APPLESCRIPT
set volumeAlias to POSIX file "$MOUNT_DIR" as alias
tell application "Finder"
  open volumeAlias
  set targetWindow to container window of volumeAlias
  set current view of targetWindow to icon view
  set toolbar visible of targetWindow to false
  set statusbar visible of targetWindow to false
  set bounds of targetWindow to {120, 120, 780, 520}
  set viewOptions to icon view options of targetWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 112
  set backgroundAlias to POSIX file "$MOUNT_DIR/$BACKGROUND_DIR_NAME/$BACKGROUND_FILE_NAME" as alias
  set background picture of viewOptions to backgroundAlias
  set position of item "$APP_NAME.app" of targetWindow to {185, 238}
  set position of item "Applications" of targetWindow to {475, 238}
  update volumeAlias without registering applications
  delay 1
  close targetWindow
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR"
MOUNT_DIR=""

hdiutil convert \
  "$RELEASE_DIR/$RW_DMG_NAME" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$RELEASE_DIR/$DMG_NAME"
rm -f "$RELEASE_DIR/$RW_DMG_NAME"

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
  echo "==> Developer ID DMG signing"
  codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$RELEASE_DIR/$DMG_NAME"
  codesign --verify --verbose=2 "$RELEASE_DIR/$DMG_NAME"

  echo "==> Notarization"
  xcrun notarytool submit \
    "$RELEASE_DIR/$DMG_NAME" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait

  echo "==> Staple notarization ticket"
  xcrun stapler staple "$RELEASE_DIR/$DMG_NAME"
  xcrun stapler validate "$RELEASE_DIR/$DMG_NAME"
  spctl -a -vv -t open --context context:primary-signature "$RELEASE_DIR/$DMG_NAME"
fi

echo "==> Checksum"
(
  cd "$RELEASE_DIR"
  shasum -a 256 "$DMG_NAME" > "$CHECKSUM_NAME"
)

echo "Created $RELEASE_DIR/$DMG_NAME"
echo "Created $RELEASE_DIR/$CHECKSUM_NAME"
