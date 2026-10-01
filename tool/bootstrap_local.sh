#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "==> Supported toolchain"
bash tool/check_toolchain.sh

echo "==> Flutter toolchain"
flutter --version
dart --version

echo "==> Generating standard Flutter platform scaffolding"
(
  cd apps/pos
  flutter create --org com.sarisupply --project-name sarisupply_pos --platforms=android .
)
(
  cd apps/driver
  flutter create --org com.sarisupply --project-name sarisupply_driver --platforms=android .
)
(
  cd apps/admin
  flutter create --org com.sarisupply --project-name sarisupply_admin --platforms=web .
)

echo "==> Bootstrapping workspace"
dart pub get
dart run melos bootstrap

echo "==> Verifying source and builds"
bash tool/verify_local.sh

echo "SariSupply Flutter foundation is ready."
