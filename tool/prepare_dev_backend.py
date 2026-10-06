#!/usr/bin/env python3
"""Prepare private Development settings; never deploy or print secrets."""
import argparse
import json
import os
from pathlib import Path
import secrets

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("service_account", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = args.output.expanduser().resolve()
source = args.service_account.expanduser().resolve()
if output.is_relative_to(root) or source.is_relative_to(root):
    parser.error("Keep credential files outside the repository")
account = json.loads(source.read_text())
if (account.get("type") != "service_account" or
        account.get("project_id") != "sarisupply-dev-aracena18" or
        not account.get("client_email") or not account.get("private_key")):
    parser.error("Use a Firebase Development service-account JSON")
settings = {
    "SARISUPPLY_ENVIRONMENT": "dev",
    "FIREBASE_PROJECT_ID": "sarisupply-dev-aracena18",
    "FIREBASE_SERVICE_ACCOUNT_JSON": json.dumps(account, separators=(",", ":")),
    "CASHIER_PIN_PEPPER": secrets.token_urlsafe(48),
    "ALLOWED_ORIGINS": ",".join([
        "https://sarisupply-dev-aracena18.web.app",
        "https://sarisupply-dev-aracena18.firebaseapp.com",
        "http://localhost:8002", "http://127.0.0.1:8002",
    ]),
    "ALLOWED_APP_IDS": ",".join([
        "1:594903185972:android:0344c52bad5280009b6861",
        "1:594903185972:android:035ca91c2f446c559b6861",
        "1:594903185972:web:e372a71146e37d499b6861",
    ]),
}
# Exclusive creation preserves the pepper used by existing cashier credentials.
output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(descriptor, "w") as private_file:
    json.dump(settings, private_file)
    private_file.write("\n")
print(f"Private Development settings prepared: {output}")
