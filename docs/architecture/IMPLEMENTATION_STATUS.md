# SariSupply implementation status

Updated: 2026-09-27

The production roadmap is in `SARI_SUPPLY_PRODUCTION_PLAN.md`. The current
implementation focus is the identity, tenant, device, and cashier authentication
milestone in `docs/superpowers/plans/2026-09-26-firebase-identity-tenant-auth.md`.

## Implemented

- Flutter POS, Driver, and Admin foundation apps with shared packages and
  Android `dev`/`prod` flavors.
- Firebase package scaffolding and restrictive Firestore and Storage rules.
- Separate Firebase Development and Production projects, three registered apps
  in each project, generated FlutterFire configurations, and Google Sign-In.
- Default Firestore databases in `asia-southeast1` with delete protection and
  deployed authorization rules in both projects.
- Development Android debug SHA-1 and SHA-256 fingerprints registered for POS
  and Driver.
- Environment-selected Firebase initialization in all apps, Google human Auth
  adapter, and separate named device Auth adapter.
- Backend authorization, idempotency, audit, and trusted Admin grant helpers,
  with tested Firestore rules deployed to both projects.
- Merchant application draft, submission, Admin review, rejection/resubmission,
  and idempotent approval logic, with callable endpoints and a Flutter adapter.
- Owner-only branch creation/deactivation, Manager invitations and acceptance,
  Manager access changes/removal, and Flutter membership and branch gateways.
- POS device activation, custom-token identity, branch-scoped revocation, and
  protected bootstrap, with separate human and device Firebase Auth sessions.
- Server-side cashier creation, suspension, PIN verification/change/reset,
  five-failure lockout, and seven-day credential bundle metadata. PIN hashes
  use scrypt and a Secret Manager pepper; the verifier never reaches clients.
- Firestore rules and indexes for personal merchant discovery and active branch
  queries deployed to both Firebase projects.
- Tenant and auth records, branch-scoped Owner/Manager policy, and an offline
  credential age/version/clock policy.
- POS local PIN derivation using PBKDF2-HMAC-SHA256 with 210,000 iterations,
  a 16-byte random salt, and a 32-byte verifier.
- Keystore-backed POS credential storage, online enrollment after permanent
  PIN verification, seven-day offline login checks, and local retry cooldowns.

## Still needed for the authentication milestone

- Cloud Functions deployment and Secret Manager pepper provisioning after
  billing is linked to the Firebase projects.
- Admin pre-authorization of an existing signed-in user, POS/Admin login
  screens, and end-to-end device activation and cashier enrollment UI.
- Upload of queued offline PIN failure events after connectivity returns.

The POS, Driver, and Admin applications still show foundation screens. Sales,
inventory, warehouse, delivery, and reporting are later milestones.

Both new projects are currently on the no-cost Spark plan. Cloud Storage
bucket creation and Cloud Functions deployment require a linked billing account
and the Blaze plan. Production Android release signing and its certificate
fingerprints must be configured before a production release.

## Verification

`dart run melos run verify` passes for all eight workspace packages.
Both Android dev debug APKs build with `flutter build apk --debug --flavor dev`.
