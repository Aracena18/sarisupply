# SariSupply Current State

**Last reviewed:** 2026-10-02

This document describes implementation reality on `main`.

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

## Verification

On 2026-10-02, the following passed on `main`:

- `bash tool/verify_fast.sh`
- `bash tool/verify_firebase.sh`: 54 tests passed across 14 files.
- `bash tool/verify_harness.sh`
- Admin web build.
- POS Android `devDebug` APK build.
- Driver Android `devDebug` APK build.

Verification used Flutter 3.44.9, Dart 3.12.2, Node 22.22.1, and the JDK selected by Flutter (Java 25).

## Operational work still outstanding

The merged implementation is not yet a production deployment. Remaining work includes:

- Deploy Cloud Functions and provision the cashier PIN pepper in Secret Manager after billing is linked to the Firebase projects.
- Pre-authorize the real Admin user and complete live end-to-end testing of device activation and cashier enrollment.
- Upload queued offline PIN failure events after connectivity returns.
- Review the separate offline-auth resilience follow-up for retaining verified POS tenant context offline and syncing queued security events. Those changes were excluded from PR #2.

The Driver app still shows a foundation screen. POS currently unlocks an authenticated cashier session; sales, inventory, warehouse, delivery, and reporting remain later milestones.

Both Firebase projects are on the no-cost Spark plan. Cloud Functions deployment and Cloud Storage bucket creation require linked billing and the Blaze plan. Production Android release signing and its certificate fingerprints must be configured before release.
