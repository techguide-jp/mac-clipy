#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "SwiftFormat is required for formatting." >&2
  exit 1
fi

swiftformat Sources Tests Package.swift --cache ignore
