# SariSupply Current State

**Last reviewed:** 2026-10-03

This document describes the checked-in implementation; deployment and live-device validation are recorded separately.

## Product stage

SariSupply is in early production-foundation development. The approved direction is a Flutter-only client architecture with POS, Driver, and Admin applications, shared Dart/Flutter packages, Firebase cloud services, and a future Drift/SQLite offline transaction layer.

## Main branch

`main` contains the Flutter monorepo foundation, the engineering harness, and the Firebase identity and tenant-auth milestone. The identity milestone, Tasks 1–11, was merged in PR #2.

### Engineering harness

The repository-level harness is merged and provides agent guidance, engineering source-of-truth documentation, architecture checks, and fast/full verification commands.

### Firebase identity milestone

Tasks 1–11 are implemented and covered by automated tests:

- Task 1: Firebase environments, Android flavors, and package/backend scaffolding.
- Task 2: tenant/auth models, immutable collections, and branch/offline authorization policies.
- Task 3: environment-specific Firebase bootstrap and separate human/device authentication.
- Task 4: backend authorization, auditing, idempotency, Admin bootstrap, and restrictive rules.
- Task 5: merchant applications, Admin review, and approval flow.
- Task 6: memberships, branch management, and Manager invitations.
- Task 7: POS device activation, scoped identity, and revocation.
- Task 8: server-side cashier lifecycle and PIN security.
- Task 9: device-local verifier and seven-day offline credential policy.
- Task 10: onboarding, activation, cashier, and Admin application states.
- Task 11: Firebase emulator acceptance tests and verification commands.

## Offline-auth resilience follow-up

The offline-auth resilience follow-up extends the identity
milestone with:

- Securely retained merchant, branch, and device context for offline POS
  recovery, limited to seven days by same-boot monotonic clock evidence. Missing
  clock evidence, reboot, or a server revocation requires online recovery.
- Durable offline cashier PIN failure reports with stable event IDs, legacy
  queue migration, retry-safe device-authenticated upload, and server-derived
  tenant, branch, and device audit context. Upload failures and partial
  acknowledgements keep pending events queued; explicit local device-session
  clearing removes device-scoped state. Authoritative bootstrap denial clears cached context and cashier credentials before best-effort device sign-out, while retaining pending audit events. The queue is bounded at 200; a full
  queue requires online refresh before another offline PIN attempt.
- Regression and emulator coverage for expiry, clock reset/manipulation,
  retries, revocation followed by offline retry, unauthenticated callers, and cross-tenant/cross-branch isolation.
- Complete stored-event validation quarantines malformed payloads without deleting them. Valid events can still sync and online authentication remains usable; offline PIN attempts remain blocked until the corrupt queue state is explicitly resolved.
- Offline PIN reports require current cashier assignment to the reporting device branch. Reports after branch reassignment are rejected and retained locally; historical assignment proof is not implemented. A suspended cashier still assigned to the branch may have past failures reported.

This follow-up is implemented with regression coverage. It is not deployed or validated on a live device.

## Verification

On 2026-10-03, the full harness passed on `chore/firebase-dependency-security`, based on the merged `main` implementation:

- `bash tool/verify_fast.sh` — PASS.
- `bash tool/verify_firebase.sh` — PASS; 54 tests passed across 14 files.
- `bash tool/verify_harness.sh` — PASS.
- Admin web build — PASS.
- POS Android `devDebug` APK build — PASS.
- Driver Android `devDebug` APK build — PASS.

Verification used Flutter 3.44.9, Dart 3.12.2, Node 22.22.1, and the JDK selected by Flutter (Java 25).

On 2026-10-03, `feat/offline-auth-resilience` also passed the full harness after
the offline-auth follow-up: 56 Firebase emulator tests across 14 files, Admin
web build, POS Android `devDebug` build, and Driver Android `devDebug` build all
passed. Flutter 3.44.9, Dart 3.12.2, Node 22.22.1, and Flutter's selected JDK
(Java 25) were used.

After the PR #5 review fixes on 2026-10-03, both `verify_fast.sh` and
`verify_harness.sh` passed: 120 Flutter tests, 59 Firebase tests across 14 files,
Admin web, POS Android `devDebug`, and Driver Android `devDebug` builds.
Independent security review found no remaining blocking findings. Regressions
cover observed revocation followed by network loss, malformed queued records,
partial acknowledgements, legacy event-ID collisions, and same-merchant
cross-branch reports. The full onboarding/PIN acceptance test uses a 15-second
timeout for cold emulator startup; its assertions and PIN derivation are unchanged.

## Firebase Functions dependency security

The 2026-10-03 npm audit reported seven affected-package entries (five high and two moderate). Triage found that the high entries are one gRPC advisory propagated through a development-only emulator-testing dependency chain; the production-only audit reports no high findings. The two moderate entries are one UUID advisory in an optional transitive Cloud Storage dependency chain, with no affected UUID or Cloud Storage API use in the current Functions source. Both findings are temporarily accepted pending upstream dependency updates. See [Firebase Functions dependency triage](FIREBASE_FUNCTIONS_DEPENDENCY_TRIAGE.md) for paths, evidence, and reevaluation conditions.

## Operational work still outstanding

The merged implementation is not yet a production deployment. Remaining work includes:

- Deploy Cloud Functions and provision the cashier PIN pepper in Secret Manager after billing is linked to the Firebase projects.
- Pre-authorize the real Admin user and complete live end-to-end testing of device activation and cashier enrollment.
- Complete live-device validation of offline tenant-context recovery and queued security-event upload after reconnect.

The Driver app still shows a foundation screen. POS currently unlocks an authenticated cashier session; sales, inventory, warehouse, delivery, and reporting remain later milestones.

Both Firebase projects are on the no-cost Spark plan. Cloud Functions deployment and Cloud Storage bucket creation require linked billing and the Blaze plan. Production Android release signing and its certificate fingerprints must be configured before release.
