#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
firebase_root="$repo_root/firebase"

if [[ ! -f "$firebase_root/firebase.json" ]]; then
  echo "Firebase verification: NOT APPLICABLE on this branch (firebase/firebase.json is absent)."
  exit 0
fi

functions_dir="$firebase_root/functions"
if [[ ! -f "$functions_dir/package.json" ]]; then
  echo "Firebase workspace exists but firebase/functions/package.json is missing." >&2
  exit 1
fi

command -v node >/dev/null || { echo "node is required for Firebase verification" >&2; exit 1; }
command -v npm >/dev/null || { echo "npm is required for Firebase verification" >&2; exit 1; }

echo "==> Firebase Functions dependencies"
cd "$functions_dir"
if [[ -f package-lock.json ]]; then
  npm ci
else
  echo "package-lock.json is absent; using npm install for the current scaffold."
  npm install
fi

echo "==> Firebase Functions build"
npm run build

function_tests=0
if [[ -d "$functions_dir/test" ]]; then
  function_tests="$(find "$functions_dir/test" -type f \( -name '*.test.ts' -o -name '*.spec.ts' \) | wc -l | tr -d ' ')"
fi

backend_tests=0
if [[ -d "$firebase_root/tests" ]]; then
  backend_tests="$(find "$firebase_root/tests" -type f \( -name '*.test.ts' -o -name '*.spec.ts' \) | wc -l | tr -d ' ')"
fi

if [[ "$function_tests" == "0" && "$backend_tests" == "0" ]]; then
  echo "Firebase tests: NOT APPLICABLE yet (no backend test files are present)."
  echo "FIREBASE VERIFICATION PASS (build only)"
  exit 0
fi

if ! command -v firebase >/dev/null; then
  echo "Firebase tests exist, but Firebase CLI is not installed." >&2
  exit 1
fi

echo "==> Firebase emulator tests"
test_command="cd functions && npx vitest run"
if [[ "$backend_tests" != "0" ]]; then
  test_command="$test_command ../tests"
fi

firebase emulators:exec \
  --project demo-sarisupply \
  --only auth,firestore,functions,storage \
  "$test_command"

echo "FIREBASE VERIFICATION PASS"
