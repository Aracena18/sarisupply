#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bash tool/check_toolchain.sh

dart pub get
dart run melos bootstrap
dart run melos run verify

if [[ -d apps/admin/web ]]; then
  (
    cd apps/admin
    flutter build web --release --dart-define=SARISUPPLY_ENV=dev
  )
else
  echo "Admin web scaffold is missing; run bash tool/bootstrap_local.sh first."
fi

build_android_app() {
  local app_dir="$1"
  local label="$2"
  local gradle_file="$app_dir/android/app/build.gradle.kts"

  if [[ ! -d "$app_dir/android" ]]; then
    echo "$label Android scaffold is missing; run bash tool/bootstrap_local.sh first."
    return
  fi

  if [[ -f "$gradle_file" ]] && grep -q 'create("dev")' "$gradle_file"; then
    (
      cd "$app_dir"
      flutter build apk --debug --flavor dev --dart-define=SARISUPPLY_ENV=dev
    )
  else
    (
      cd "$app_dir"
      flutter build apk --debug
    )
  fi
}

build_android_app "apps/pos" "POS"
build_android_app "apps/driver" "Driver"
