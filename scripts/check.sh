#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Swift version"
swift --version

if command -v swiftlint >/dev/null 2>&1; then
  echo "==> SwiftLint"
  swiftlint lint --strict
elif [[ "${REQUIRE_SWIFTLINT:-0}" == "1" ]]; then
  echo "SwiftLint is required but was not found." >&2
  exit 1
else
  echo "==> SwiftLint not found; skipping local lint"
fi

if command -v swiftformat >/dev/null 2>&1; then
  echo "==> SwiftFormat"
  swiftformat --lint Sources Tests Package.swift
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
test "$(plutil -extract LSMinimumSystemVersion raw dist/MacClipy.app/Contents/Info.plist)" = "14.0"

echo "All checks passed."
