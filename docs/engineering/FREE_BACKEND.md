# Free trusted backend: local implementation and deployment gate

The approved [platform scope](../superpowers/specs/2026-10-04-free-production-platform.md)
keeps Firebase on Spark. The HTTPS adapter runs privileged Firebase Admin services
on Deno Deploy Free, with Firestore as its only persistent cloud database.

## Current gate

On 2026-10-06 the operator supplied Development Firebase and Deno credentials.
Credentials are privately stored outside the repository. Deno organization
`aracena18` was verified on the Free plan. The Development application
`aracena18-sarisupply-dev-api` is deployed at
`https://aracena18-sarisupply-dev-api.aracena18.deno.net`, revision `42wrrxfpnyd4`;
The Firebase App Check API responds successfully, and the operator-selected
Admin account has its Development role and custom claim. Runtime secrets are
restricted to runtime production/preview contexts within the Development app,
excluding the build context.
Hosted startup and routing passed. Live-client acceptance is not yet verified. Firebase billing
has not been linked. Local tests cannot prove account eligibility, free quotas, live
App Check, cold-start performance, or real traffic capacity. Hosted acceptance
remains pending here and in `CURRENT_STATE.md`. After local Phase 1
verification, the operator explicitly instructed local Phase 2 implementation.
That exception permits local identity/UX work; account, live SDK and capacity
evidence remain pending and no pilot or hosted-feasibility claim is authorized.

No business-service logic or PIN derivation is replaced. The 21 command names
and output shapes are preserved. `firebase-functions` is retained for existing
emulator callables and the typed error contract; it does not require deploying
Functions or accessing Secret Manager. Production factories select HTTPS with
explicit configuration. There is no paid callable fallback.

The hosted adapter uses Firebase Admin's supported `preferRest` transport. Deno
2.5's default Node gRPC path timed out on the local transaction probe; REST passed
the same transaction and identity checks. No server snapshot listeners are used.
The emulator probe uses its admin token with an OAuth2 AuthClient to avoid REST's
ADC and signed-token mismatch. That fixture exists only in the loopback-guarded
test; hosted startup accepts certificate credentials exclusively. Live IAM and
service-account token exchange still require Development acceptance.

## Local verification

Use Flutter 3.44.9, Dart 3.12.2 and Node 22. Deno 2.5.0 is pinned as a development
dependency because it is the runtime currently advertised by Deploy. It is not
a runtime database or a paid service.

```bash
bash tool/verify_harness.sh
```

The Firebase path builds the existing TypeScript workspace, runs domain/rules
and HTTPS tests against `demo-sarisupply-rules`, then runs a Deno acceptance probe.
The probe checks a Node-generated scrypt reference, Admin SDK imports, Firestore
transactions, custom-token signing, real emulator ID-token verification and the
HTTP bridge. It uses loopback emulators exclusively. Test attestation is injected
because App Check has no emulator; the hosted entrypoint always verifies actual
App Check tokens and has no bypass setting.

`http` is an explicit shared Firebase adapter dependency for Android/Web HTTPS
and abortable requests. `firebase_app_check` supplies attestation for the custom
backend. The gateway retains `FirebaseFunctionsException` codes consumed by POS
offline/revocation logic. App Check failures, verifier/network outages and endpoint
configuration denials reject online commands with `unavailable`; they preserve
cached offline authority only within its existing trusted window. Verified Auth
revocation/disablement and domain device denials still invalidate offline credentials.
Auth verification precedes attestation so known revocation remains authoritative.
A timeout may have an uncertain server outcome;
existing operation IDs must be retained for safe retries.

The POS's `http` development dependency supports regression tests through the
actual HTTPS gateway and device repository; application production code continues
to use the Firebase adapter.

## Server configuration

Configure a separate deployment for Development and Production. Store secrets in
the hosting account's secret environment settings; never commit them or put them
in client build defines. Required server settings:

| Setting | Value |
| --- | --- |
| `SARISUPPLY_ENVIRONMENT` | `dev` or `prod` |
| `FIREBASE_PROJECT_ID` | `sarisupply-dev-aracena18` or `sarisupply-prod-aracena18`, matching environment |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Server-only service account JSON for that project |
| `CASHIER_PIN_PEPPER` | Server-only random secret, at least 32 characters; retain securely for credential continuity |
| `ALLOWED_ORIGINS` | Comma-separated exact Admin HTTPS origins; dev may use explicit localhost HTTP origins |
| `ALLOWED_APP_IDS` | Comma-separated registered Firebase application IDs; no wildcard |
| `PORT` | Optional; defaults to 8000 |

Service account permissions must cover the existing Firestore/Auth operations,
custom token signing and App Check verification. Use only the roles needed by
these operations; do not grant project Owner. Verify permissions in Development
before copying the deployment configuration to Production. Protect and rotate
the service account key; changing the PIN pepper requires a credential migration.

Hosted startup rejects missing configuration, mismatched credentials/project,
wildcard origins and emulator settings. Auth tokens are checked with revocation
enabled. SDK verification checks the App Check token's project; the adapter also
checks the registered application ID. Current Firestore role/device state remains
the source of authority. CORS is only a browser restriction, not authorization.

## Prepare a Deno Deploy Free application

1. Create the account/organization and verify the **actual** Free limits and account
   restrictions. Do not select Pro/Builder, link Firebase billing, or accept a paid
   upgrade. If free access cannot be confirmed, keep the gate closed.
2. Use current Deno Deploy, not Deploy Classic. Connect a reviewed revision of this
   repository. No KV, second database, object storage or paid add-on is needed.
3. Set app/build working directory to `firebase/functions`. `deno.json` explicitly selects the Development organization/application,
   locked installation with `npm ci --include=dev`, build with `npm run build && npm prune --omit=dev`,
   and dynamic runtime entrypoint `lib/https/main.js`. Source configuration
   prevents automatic detection from choosing the Cloud Functions entrypoint. Deploy's builder executes its Node/npm shims through Deno;
   local repository verification still uses Node 22. Keep the TypeScript development
   dependency installed until compilation completes, then remove build-only dependencies
   from the runtime artifact.
   For the presentation, local `npm run build` passed and compiled `lib/` plus
   package/configuration files were uploaded through the official REST deploy API.
   This artifact installs with `npm ci --omit=dev` and needs no cloud compiler.
   CLI uploads timed out while waiting for source files; inline REST assets avoid
   the incomplete upload. The deployed revision passed warmup and routing; connected-client acceptance
   remains pending.
4. Configure the Deno runtime entrypoint as `lib/https/main.js` and required settings
   above. Deno executes compiled CommonJS using the explicit package type. Local
   equivalent: `npx --no-install deno run --allow-env --allow-read --allow-net --allow-sys lib/https/main.js`.
   Deploy itself grants runtime permissions; no nonstandard flags are required.
5. Deployment/publishing is a separate operator action after reviewing code and
   configuration. Use Development first. Record actual runtime/version, endpoint,
   account limits and permission evidence here, without secrets.
6. Confirm browser preflight, real App Check, Google login, Admin approval, device
   activation, permanent PIN, retries and revocation on actual Android/Web clients.
   Confirm cold starts and cross-tenant denials. Local attestation fixtures do not
   substitute for these checks.

Public client build defines:

```text
SARISUPPLY_ENV=dev
SARISUPPLY_API_URL=https://<development-backend-origin>
SARISUPPLY_APP_CHECK_WEB_KEY=<registered-recaptcha-v3-site-key>
```

The endpoint must be a root HTTPS origin; no credentials, query parameters or
path. Admin uses the web site key. Development Android uses the App Check debug
provider; register only Development debug tokens. Production Android uses Play
Integrity and requires correct release-signing registration and distribution
settings. Register each Firebase app used by the client; human and device Auth
remain separate sessions even when they share the same application ID.

Play Integrity setup also requires suitable Google Play Console access under the
official provider instructions. Existing access and outside-Play distribution
settings must be verified before release. No paid developer-account purchase is
authorized by this plan. If setup needs a paid account the operator does not have,
resolve that free-provider constraint before production acceptance; never replace
production attestation with debug tokens.

## Capacity evidence

`FREE_CAPACITY_PROFILE.json` deliberately contains null observations and false
evidence flags. Do not substitute optimistic numbers to make the gate green.

```bash
cd firebase/functions
npm run build
npm run check:capacity
```

Exit 0 means the supplied evidence fits engineering budgets; exit 1 means invalid
or over-budget; exit 2 means unproven. This is an evidence worksheet, not a billing
enforcer or proof that the entire platform is ready. Record how every observation
was measured. Include all other platform workflows, denied requests, ID-token
revocation lookups, App Check, transaction retries, reconnects, bootstrap/downloads,
reports, indexes, open balances, archive verification and deletions. Retention
must be demonstrably feasible; the actual archive restore remains a release gate.

Firebase budgets are 40,000 reads, 16,000 writes and 16,000 deletes/day, and 750 MiB
including indexes. Hosting uses 80% of published Free ceilings: 800,000 requests,
8 CPU hours, 16 GiB egress and 120 GiB-hours loaded-instance memory/month.

**Memory time may be the binding limit.** At a 768 MiB allocation, one continuously
loaded instance for 12 hours/day over 30 days consumes 270 GiB-hours, exceeding
the published 150 GiB-hour Free allowance. Multiple instances add their occupancy.
Process RSS and active CPU are not substitutes for billed loaded-instance time.
Measure actual bursts, idle shutdowns, cold starts and instance counts. Spreading
polling throughout the day can exhaust the free budget even at low sales volume.

Firestore fixture storage must include all five lines/receipt, immutable facts,
stock/credit changes, operation receipts and indexes. Test initial 3,000-SKU
downloads to both POS devices per store and avoid repeating full downloads daily.
Measure retention maintenance too; TTL and managed backups requiring billing are
not part of the design. Free quota exhaustion must preserve pending local work.

If the account or representative traffic cannot fit these limits, report the
failing constraint and revise free compute/sync scheduling before Phase 2. Do not
weaken security, add another cloud database or silently choose paid infrastructure.

Primary references checked 2026-10-04:
[Deno runtime](https://docs.deno.com/deploy/reference/runtime/),
[Deno builds](https://docs.deno.com/deploy/reference/builds/),
[Deno pricing](https://deno.com/deploy/pricing),
[Firestore quotas](https://firebase.google.com/docs/firestore/quotas),
[custom-backend App Check](https://firebase.google.com/docs/app-check/custom-resource-backend).
