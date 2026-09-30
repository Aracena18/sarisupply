#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "========================================"
echo "SariSupply Engineering Harness"
echo "========================================"

echo "==> Harness structure and architecture"
bash tool/verify_fast.sh

echo "==> Application build verification"
bash tool/verify_local.sh

echo "==> Firebase verification"
bash tool/verify_firebase.sh

echo "========================================"
echo "SARI SUPPLY HARNESS VERIFICATION PASS"
echo "========================================"
