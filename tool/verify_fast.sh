#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required_files=(
  "AGENTS.md"
  "docs/engineering/README.md"
  "docs/engineering/CURRENT_STATE.md"
  "docs/engineering/AGENT_WORKFLOW.md"
  "docs/engineering/DEFINITION_OF_DONE.md"
  "docs/engineering/ARCHITECTURE_BOUNDARIES.md"
  "tool/check_architecture.dart"
)

echo "==> Harness structure"
for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing required harness file: $path" >&2
    exit 1
  fi
done
echo "Harness structure PASS"

command -v dart >/dev/null || { echo "dart is required" >&2; exit 1; }
command -v flutter >/dev/null || { echo "flutter is required" >&2; exit 1; }

echo "==> Workspace bootstrap"
dart pub get
dart run melos bootstrap

echo "==> Architecture boundaries"
dart tool/check_architecture.dart

echo "==> Formatting"
dart run melos run format

echo "==> Static analysis"
dart run melos run analyze

echo "==> Tests"
dart run melos run test

echo "FAST VERIFICATION PASS"
