#!/usr/bin/env bash
set -euo pipefail

required_flutter="3.44.9"
required_dart="3.12.2"

command -v flutter >/dev/null || { echo "flutter is required" >&2; exit 1; }
command -v dart >/dev/null || { echo "dart is required" >&2; exit 1; }

flutter_line="$(flutter --version | head -n 1)"
actual_flutter="$(printf '%s\n' "$flutter_line" | awk '{print $2}')"
actual_dart="$(dart --version 2>&1 | sed -E 's/.*version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"

if [[ "$actual_flutter" != "$required_flutter" ]]; then
  echo "Flutter toolchain mismatch: expected $required_flutter, got $actual_flutter" >&2
  exit 1
fi

if [[ "$actual_dart" != "$required_dart" ]]; then
  echo "Dart toolchain mismatch: expected $required_dart, got $actual_dart" >&2
  exit 1
fi

echo "Toolchain PASS: Flutter $actual_flutter / Dart $actual_dart"
