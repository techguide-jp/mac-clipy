#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="MacClipy"
APP_VERSION="${APP_VERSION:-0.1.0}"
RELEASE_TAG="${RELEASE_TAG:-v$APP_VERSION}"
RELEASE_DIR="$ROOT_DIR/dist/release"
APPCAST_NAME="${APPCAST_NAME:-appcast.xml}"
DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/techguide-jp/mac-clipy/releases/download/$RELEASE_TAG/}"
GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-}"
DMG_PATH="$RELEASE_DIR/$APP_NAME-v$APP_VERSION.dmg"

if [[ "$APP_VERSION" == v* ]]; then
  echo "APP_VERSION should not include the leading v. Use APP_VERSION=${APP_VERSION#v}." >&2
  exit 1
fi

if [[ -z "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  echo "SPARKLE_ED_PRIVATE_KEY is required to generate a signed Sparkle appcast." >&2
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Release DMG not found: $DMG_PATH" >&2
  exit 1
fi

if [[ -z "$GENERATE_APPCAST" ]]; then
  GENERATE_APPCAST="$(
    find "$ROOT_DIR/.build" -type f -name generate_appcast -print 2>/dev/null | head -n 1 || true
  )"
fi

if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast tool was not found or is not executable." >&2
  exit 1
fi

echo "==> Sparkle appcast"
printf "%s" "$SPARKLE_ED_PRIVATE_KEY" | "$GENERATE_APPCAST" \
  --ed-key-file - \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  -o "$RELEASE_DIR/$APPCAST_NAME" \
  "$RELEASE_DIR"

test -f "$RELEASE_DIR/$APPCAST_NAME"
echo "Created $RELEASE_DIR/$APPCAST_NAME"
