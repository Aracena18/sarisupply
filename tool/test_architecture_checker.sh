#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p   "$tmp_root/apps/pos/lib"   "$tmp_root/apps/admin/lib"   "$tmp_root/packages/example/lib"

cat > "$tmp_root/apps/pos/lib/bad.dart" <<'DART'
import 'package:sarisupply_admin/main.dart';

void main() {}
DART

if (
  cd "$tmp_root"
  dart "$repo_root/tool/check_architecture.dart" >/dev/null 2>&1
); then
  echo "Architecture checker self-test FAILED: cross-app import was accepted." >&2
  exit 1
fi

rm "$tmp_root/apps/pos/lib/bad.dart"

cat > "$tmp_root/apps/pos/lib/good.dart" <<'DART'
import 'package:sarisupply_core/sarisupply_core.dart';

void main() {}
DART

if ! (
  cd "$tmp_root"
  dart "$repo_root/tool/check_architecture.dart" >/dev/null
); then
  echo "Architecture checker self-test FAILED: valid shared-package import was rejected." >&2
  exit 1
fi

echo "Architecture checker self-test PASS"
