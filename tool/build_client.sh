#!/usr/bin/env bash
# Build only. Installation and deployment are separate operator actions.
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo 'Usage: bash tool/build_client.sh <pos|admin|driver> <dev|prod> <apk-debug|apk-release|web> <public-settings.json>' >&2
  exit 2
fi
app="$1"
environment="$2"
target="$3"
settings_file="$4"
case "$app" in pos|admin|driver) ;; *) echo 'Unknown application' >&2; exit 2 ;; esac
case "$environment" in dev|prod) ;; *) echo 'Unknown environment' >&2; exit 2 ;; esac
case "$target" in apk-debug|apk-release|web) ;; *) echo 'Unknown build target' >&2; exit 2 ;; esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings_file="$(realpath "$settings_file")"
python3 - "$settings_file" "$environment" "$target" <<'PY'
import json, sys
from urllib.parse import urlsplit
settings = json.load(open(sys.argv[1], encoding='utf-8'))
allowed = {'SARISUPPLY_ENV', 'SARISUPPLY_API_URL', 'GOOGLE_SERVER_CLIENT_ID', 'SARISUPPLY_APP_CHECK_WEB_KEY', 'SARISUPPLY_APP_CHECK_WEB_PROVIDER'}
if not isinstance(settings, dict) or set(settings) - allowed:
    raise SystemExit('Settings must contain only approved public client keys. Never include server credentials.')
if settings.get('SARISUPPLY_ENV') != sys.argv[2]:
    raise SystemExit('Client settings environment must match the requested build flavor.')
origin = settings.get('SARISUPPLY_API_URL', '')
if not isinstance(origin, str):
    raise SystemExit('A public HTTPS backend origin is required.')
try:
    parsed = urlsplit(origin)
    valid = (origin == origin.strip() and parsed.scheme == 'https' and parsed.hostname
             and not parsed.hostname.endswith('.internal') and not parsed.username
             and not parsed.password and parsed.path in ('', '/') and not parsed.query
             and not parsed.fragment and parsed.port != 0)
except ValueError:
    valid = False
if not valid:
    raise SystemExit('A public HTTPS origin without credentials, path, query or fragment is required.')
if sys.argv[3] == 'web' and not str(settings.get('SARISUPPLY_APP_CHECK_WEB_KEY', '')).strip():
    raise SystemExit('Web builds require the public SARISUPPLY_APP_CHECK_WEB_KEY site key.')
if settings.get('SARISUPPLY_APP_CHECK_WEB_PROVIDER', 'recaptcha-v3') not in {'enterprise', 'recaptcha-v3'}:
    raise SystemExit('App Check web provider must be enterprise or recaptcha-v3.')
if any(not isinstance(value, str) for value in settings.values()):
    raise SystemExit('Public client setting values must be strings.')
PY

cd "$repo_root/apps/$app"
case "$target" in
  apk-debug) flutter build apk --debug --flavor "$environment" --dart-define-from-file="$settings_file" ;;
  apk-release) flutter build apk --release --flavor "$environment" --dart-define-from-file="$settings_file" ;;
  web) flutter build web --release --dart-define-from-file="$settings_file" ;;
esac
