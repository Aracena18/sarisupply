# SariSupply Foundation Implementation Plan

## Goal

Establish a production-oriented Flutter/Dart monorepo for the SariSupply POS, Driver, and Admin applications before adding Firebase and business features.

## Architecture

- Flutter Android for POS
- Flutter Android for Driver
- Flutter Web for Admin / Operations
- Riverpod for state management and dependency injection
- Melos for monorepo management
- Shared Flutter packages under `packages/`
- Firebase and Drift/SQLite are introduced in later milestones

## Foundation acceptance criteria

- All three application source trees exist.
- Applications share core identity and theme packages.
- Money values use integer centavos rather than floating-point arithmetic.
- Root formatting, analysis, and test commands are defined through Melos.
- Standard Android/Web platform scaffolding can be generated with `tool/bootstrap_local.sh`.
- Local verification and build commands are centralized in `tool/verify_local.sh`.
- Firebase secrets and signing credentials are excluded from Git.
- No non-Flutter frontend framework is introduced.

## CI status

GitHub Actions was tested with both the bootstrap workflow and a one-line smoke workflow. Both returned `startup_failure` before any runner/job was allocated. CI is therefore deferred until Actions is available for the repository/account.

## Next milestone

Identity + Merchant + Branch + Device foundation:

1. Firebase project/environment structure
2. Google Sign-In
3. Owner/Manager authentication
4. Merchant creation
5. Branch creation
6. Device registration/revocation
7. Cashier profiles
8. Secure PIN verification
9. Audit-event foundation
