#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

EXPECTED_BUNDLE_ID="${BUNDLE_ID:-jp.techguide.macclipy}"
EXPECTED_APP_VERSION="${APP_VERSION:-0.1.0}"
EXPECTED_BUILD_NUMBER="${BUILD_NUMBER:-1}"
EXPECTED_BUILD_ARCHS="${BUILD_ARCHS:-}"

echo "==> Swift version"
swift --version

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
test "$(plutil -extract CFBundleIdentifier raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_BUNDLE_ID"
test "$(plutil -extract CFBundleShortVersionString raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_APP_VERSION"
test "$(plutil -extract CFBundleVersion raw dist/MacClipy.app/Contents/Info.plist)" = "$EXPECTED_BUILD_NUMBER"
test "$(plutil -extract CFBundleIconFile raw dist/MacClipy.app/Contents/Info.plist)" = "AppIcon"
test "$(plutil -extract LSApplicationCategoryType raw dist/MacClipy.app/Contents/Info.plist)" = "public.app-category.productivity"
test "$(plutil -extract LSMinimumSystemVersion raw dist/MacClipy.app/Contents/Info.plist)" = "14.0"
if [[ -n "$EXPECTED_BUILD_ARCHS" ]]; then
  actual_archs="$(lipo -archs dist/MacClipy.app/Contents/MacOS/MacClipy)"
  test "$actual_archs" = "$EXPECTED_BUILD_ARCHS"
fi
codesign --verify --deep --strict --verbose=2 dist/MacClipy.app

echo "All checks passed."
