# SariSupply Implementation Status

Updated: 2026-10-03

**Historical snapshot:** The entries below preserve implementation and verification
claims from the 2026-10-03 milestone. They are not the current implementation or
deployment status, and older billing-dependent steps are superseded by the approved
free production scope. Use [Current State](../engineering/CURRENT_STATE.md) for
current status and [Canonical System Architecture](SYSTEM_ARCHITECTURE.md) for
approved ownership, roles, and system invariants. Inspect code and current evidence
before treating a historical capability or outstanding task as present-day truth.

The production roadmap is in `SARI_SUPPLY_PRODUCTION_PLAN.md`. The Firebase identity, tenant, device, and cashier-auth milestone (Tasks 1–11) is implemented and merged into `main` in PR #2. The repository implementation is verified; live deployment and operational validation remain outstanding as listed below.

## Implemented

- Flutter POS, Driver, and Admin foundation apps with shared packages and Android `dev`/`prod` flavors.
- Firebase package scaffolding and restrictive Firestore and Storage rules.
- Separate Firebase Development and Production projects, three registered apps in each project, generated FlutterFire configurations, and Google Sign-In.
- Default Firestore databases in `asia-southeast1` with delete protection and deployed authorization rules in both projects.
- Development Android debug SHA-1 and SHA-256 fingerprints registered for POS and Driver.
- Environment-selected Firebase initialization in all apps, Google human Auth adapter, and separate named device Auth adapter.
- Backend authorization, idempotency, audit, and trusted Admin grant helpers, with tested Firestore rules deployed to both projects.
- Merchant application draft, submission, Admin review, rejection/resubmission, and idempotent approval logic, with callable endpoints and a Flutter adapter.
- Owner-only branch creation/deactivation, Manager invitations and acceptance, Manager access changes/removal, and Flutter membership and branch gateways.
- POS device activation, custom-token identity, branch-scoped revocation, and protected bootstrap, with separate human and device Firebase Auth sessions.
- Server-side cashier creation, suspension, PIN verification/change/reset, five-failure lockout, and seven-day credential bundle metadata. PIN hashes use scrypt and a Secret Manager pepper; the verifier never reaches clients.
- Firestore rules and indexes for personal merchant discovery and active branch queries deployed to both Firebase projects.
- Tenant and auth records, branch-scoped Owner/Manager policy, and an offline credential age/version/clock policy.
- POS local PIN derivation using PBKDF2-HMAC-SHA256 with 210,000 iterations, a 16-byte random salt, and a 32-byte verifier.
- Keystore-backed POS credential storage, online enrollment after permanent PIN verification, seven-day offline login checks, and local retry cooldowns.
- POS sign-in, merchant application, device activation, cashier login, and temporary PIN change screens, plus Admin sign-in and application review UI.
- Local Auth, Firestore, and Functions emulator acceptance coverage for application approval, Manager branch scoping, device revocation, and idempotent retries.

## Offline-auth resilience follow-up

The offline-auth resilience follow-up adds securely cached POS
merchant/branch/device context with a seven-day same-boot monotonic limit and
fail-closed behavior after reboot, missing clock evidence, or server revocation.
It also adds durable offline cashier PIN failure reports with stable IDs,
retry-safe device-authenticated uploads, server-derived audit scope, and a
200-event queue limit that requires online refresh before further offline PIN
attempts. Emulator and POS regression tests cover the trust, retry, revocation,
and tenant/branch-isolation cases. On authoritative bootstrap denial, cached context and offline cashier credentials are invalidated before best-effort device sign-out; pending audit evidence is preserved. Malformed queue records are quarantined in place and block further offline PIN attempts without crashing online recovery or preventing healthy events from syncing.

Reporting requires current cashier assignment to the device branch, including for delayed reports after reassignment. Historical assignment proof is not implemented. Suspended-but-still-assigned cashier failures remain reportable. This implementation is not deployed or live-device validated.

## Operational deployment and validation still needed

- Cloud Functions deployment and Secret Manager pepper provisioning after billing is linked to the Firebase projects.
- Pre-authorization of the real Admin user and live end-to-end testing of device activation and cashier enrollment.
- Live-device validation of retained offline tenant context and queued security-event upload after reconnect.

These items are not implied complete by emulator tests or successful app builds. The Driver application still shows a foundation screen. POS currently unlocks only an authenticated cashier session; sales, inventory, warehouse, delivery, and reporting are later milestones.

Both new projects are currently on the no-cost Spark plan. Cloud Storage bucket creation and Cloud Functions deployment require a linked billing account and the Blaze plan. Production Android release signing and its certificate fingerprints must be configured before a production release.

## Verification

Latest verification on `chore/firebase-dependency-security`, based on the merged `main` implementation, on 2026-10-03:

- `bash tool/verify_fast.sh` — PASS.
- `bash tool/verify_firebase.sh` — PASS; 54 tests passed across 14 files.
- `bash tool/verify_harness.sh` — PASS.
- Admin web build — PASS.
- POS Android `devDebug` APK — PASS.
- Driver Android `devDebug` APK — PASS.

The verification environment used Flutter 3.44.9, Dart 3.12.2, Node 22.22.1, and Flutter's selected JDK (Java 25). The 2026-10-03 Firebase Functions npm audit reported seven affected-package entries (2 moderate, 5 high); their scope and temporary dispositions are recorded in [Firebase Functions dependency triage](../engineering/FIREBASE_FUNCTIONS_DEPENDENCY_TRIAGE.md). The audit used npm 10.9.4.

The 2026-10-03 full harness run on `feat/offline-auth-resilience` passed with 56
Firebase emulator tests across 14 files, plus Admin web, POS Android `devDebug`,
and Driver Android `devDebug` builds. The run used Flutter 3.44.9, Dart 3.12.2,
Node 22.22.1, and the JDK selected by Flutter (Java 25).

PR #5 review-fix verification on 2026-10-03 supersedes that test count:
`verify_fast.sh` and `verify_harness.sh` passed with 120 Flutter tests and
59 Firebase tests across 14 files. All three app builds passed, and independent
security review found no remaining blocking findings. Live deployment and
real-device validation remain outstanding.
