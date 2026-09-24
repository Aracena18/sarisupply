#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

dart pub get
dart run melos bootstrap
dart run melos run verify

if [[ -d apps/admin/web ]]; then
  (cd apps/admin && flutter build web --release)
else
  echo "Admin web scaffold is missing; run bash tool/bootstrap_local.sh first."
fi

if [[ -d apps/pos/android ]]; then
  (cd apps/pos && flutter build apk --debug)
else
  echo "POS Android scaffold is missing; run bash tool/bootstrap_local.sh first."
fi

if [[ -d apps/driver/android ]]; then
  (cd apps/driver && flutter build apk --debug)
else
  echo "Driver Android scaffold is missing; run bash tool/bootstrap_local.sh first."
fi
