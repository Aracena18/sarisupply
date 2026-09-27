# SariSupply implementation status

Updated: 2026-09-27

The production roadmap is in `SARI_SUPPLY_PRODUCTION_PLAN.md`. The current
implementation focus is the identity, tenant, device, and cashier authentication
milestone in `docs/superpowers/plans/2026-09-26-firebase-identity-tenant-auth.md`.

## Implemented

- Flutter POS, Driver, and Admin foundation apps with shared packages and
  Android `dev`/`prod` flavors.
- Firebase package scaffolding and deny-all Firestore and Storage rules.
- Tenant and auth records, branch-scoped Owner/Manager policy, and an offline
  credential age/version/clock policy.
- POS local PIN derivation using PBKDF2-HMAC-SHA256 with 210,000 iterations,
  a 16-byte random salt, and a 32-byte verifier.

## Still needed for the authentication milestone

- Separate Development and Production Firebase projects, app registrations,
  generated Flutter configuration, and enabled Google sign-in.
- Human and device Firebase bootstrap, Google authentication, and Admin
  pre-authorization.
- Protected merchant approval, membership, branch, device, and cashier Cloud
  Functions with Firestore rules and emulator tests.
- Secure device-local credential storage, online enrollment, offline login
  retry controls, and POS/Admin authentication screens.

The POS, Driver, and Admin applications still show foundation screens. Sales,
inventory, warehouse, delivery, and reporting are later milestones.

## Verification

`dart run melos run verify` passes for all eight workspace packages.
Both Android dev debug APKs build with `flutter build apk --debug --flavor dev`.
