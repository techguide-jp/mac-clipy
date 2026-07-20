#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

EXPECTED_BUNDLE_ID="${BUNDLE_ID:-jp.techguide.macclipy}"
EXPECTED_APP_VERSION="${APP_VERSION:-0.1.0}"
EXPECTED_BUILD_NUMBER="${BUILD_NUMBER:-1}"
EXPECTED_BUILD_ARCHS="${BUILD_ARCHS:-}"
EXPECTED_ANALYTICS_ENABLED="${ANALYTICS_ENABLED:-0}"
EXPECTED_ANALYTICS_ENDPOINT="${ANALYTICS_ENDPOINT:-https://techguide.jp/api/macclipy/analytics}"
EXPECTED_SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/techguide-jp/mac-clipy/releases/latest/download/appcast.xml}"
EXPECTED_SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=}"

echo "==> Swift version"
swift --version

echo "==> App lifecycle helper"
BUNDLE_ID=jp.techguide.macclipy.check-missing scripts/app-lifecycle.swift wait-stopped

if command -v swiftlint >/dev/null 2>&1; then
  echo "==> SwiftLint"
  swiftlint lint --strict --no-cache
elif [[ "${REQUIRE_SWIFTLINT:-0}" == "1" ]]; then
  echo "SwiftLint is required but was not found." >&2
  exit 1
else
  echo "==> SwiftLint not found; skipping local lint"
fi

if command -v swiftformat >/dev/null 2>&1; then
  echo "==> SwiftFormat"
  swiftformat Sources Tests Package.swift --lint --cache ignore
elif [[ "${REQUIRE_SWIFTFORMAT:-0}" == "1" ]]; then
  echo "SwiftFormat is required but was not found." >&2
  exit 1
else
  echo "==> SwiftFormat not found; skipping local format lint"
fi

echo "==> Tests"
swift test -Xswiftc -warnings-as-errors

echo "==> Release build"
swift build -c release -Xswiftc -warnings-as-errors

echo "==> App bundle"
scripts/build-app.sh
plutil -lint dist/MacClipy.app/Contents/Info.plist
test -x dist/MacClipy.app/Contents/MacOS/MacClipy
test -f dist/MacClipy.app/Contents/Resources/ja.lproj/Localizable.strings
test -f dist/MacClipy.app/Contents/Resources/en.lproj/Localizable.strings
test -f dist/MacClipy.app/Contents/Resources/AppIcon.icns
test -f dist/MacClipy.app/Contents/Resources/PrivacyInfo.xcprivacy
test -d dist/MacClipy.app/Contents/Resources/Defaults_Defaults.bundle
test -d dist/MacClipy.app/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle
test -d dist/MacClipy.app/Contents/Resources/MacClipy_MacClipy.bundle
test -d dist/MacClipy.app/Contents/Frameworks/Sparkle.framework
test "$(plutil -extract CFBundleIdentifier raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_BUNDLE_ID"
test "$(plutil -extract CFBundleShortVersionString raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_APP_VERSION"
test "$(plutil -extract CFBundleVersion raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_BUILD_NUMBER"
test "$(plutil -extract CFBundleIconFile raw dist/MacClipy.app/Contents/Info.plist)" = "AppIcon"
test "$(plutil -extract LSApplicationCategoryType raw dist/MacClipy.app/Contents/Info.plist)" = "public.app-category.productivity"
test "$(plutil -extract LSMinimumSystemVersion raw dist/MacClipy.app/Contents/Info.plist)" = "14.0"
test "$(plutil -extract SUFeedURL raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_SPARKLE_FEED_URL"
test "$(plutil -extract SUPublicEDKey raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_SPARKLE_PUBLIC_ED_KEY"
test "$(plutil -extract SUEnableAutomaticChecks raw dist/MacClipy.app/Contents/Info.plist)" = "true"
test "$(plutil -extract SUAutomaticallyUpdate raw dist/MacClipy.app/Contents/Info.plist)" = "false"
test "$(plutil -extract SUVerifyUpdateBeforeExtraction raw dist/MacClipy.app/Contents/Info.plist)" = "true"
test "$(plutil -extract MacClipyAnalyticsEndpoint raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_ANALYTICS_ENDPOINT"
if [[ "$EXPECTED_ANALYTICS_ENABLED" == "1" ]]; then
  test "$(plutil -extract MacClipyAnalyticsEnabled raw dist/MacClipy.app/Contents/Info.plist)" = "true"
else
  test "$(plutil -extract MacClipyAnalyticsEnabled raw dist/MacClipy.app/Contents/Info.plist)" = "false"
fi
plutil -lint dist/MacClipy.app/Contents/Resources/PrivacyInfo.xcprivacy
test "$(plutil -extract NSPrivacyTracking raw dist/MacClipy.app/Contents/Resources/PrivacyInfo.xcprivacy)" = "false"
test "$(plutil -extract NSPrivacyCollectedDataTypes.0.NSPrivacyCollectedDataType raw dist/MacClipy.app/Contents/Resources/PrivacyInfo.xcprivacy)" = "NSPrivacyCollectedDataTypeDeviceID"
test "$(plutil -extract NSPrivacyCollectedDataTypes.1.NSPrivacyCollectedDataType raw dist/MacClipy.app/Contents/Resources/PrivacyInfo.xcprivacy)" = "NSPrivacyCollectedDataTypeProductInteraction"
if [[ -n "$EXPECTED_BUILD_ARCHS" ]]; then
  actual_archs="$(lipo -archs dist/MacClipy.app/Contents/MacOS/MacClipy)"
  test "$actual_archs" = "$EXPECTED_BUILD_ARCHS"
fi
codesign --verify --deep --strict --verbose=2 dist/MacClipy.app

echo "All checks passed."
