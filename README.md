# SariSupply

SariSupply is an **offline-first retail operating system and distribution platform** for medium-sized sari-sari stores.

## Flutter everywhere

All user-facing applications in SariSupply use **Flutter**:

- `apps/pos` — SariSupply POS for Android tablets/mobile devices
- `apps/driver` — SariSupply Driver for Android
- `apps/admin` — SariSupply Admin / Operations for Flutter Web

There is no React or Next.js frontend in the approved architecture.

## Monorepo

The workspace is managed with **Melos** and **Riverpod**.

Shared packages:

- `packages/sarisupply_core`
- `packages/sarisupply_models`
- `packages/sarisupply_design_system`

Applications must not import one another directly.

## Backend direction

Firebase will provide Authentication, Firestore, Cloud Functions, Storage, FCM, App Check, and Crashlytics. The POS will later use **Drift/SQLite** for durable offline-first transactions and synchronization.

## First local setup

Clone the repository and generate the standard Flutter Android/Web platform folders:

```bash
git clone https://github.com/Aracena18/sarisupply.git
cd sarisupply
bash tool/bootstrap_local.sh
```

That command will generate:

- Android platform files for POS
- Android platform files for Driver
- Web platform files for Admin
- workspace dependencies
- tests, analysis, and debug/release build verification

## Verify again

```bash
bash tool/verify_local.sh
```

## Engineering harness

Coding agents and contributors should start with `AGENTS.md`.

Engineering source of truth:

- `docs/engineering/README.md`
- `docs/engineering/CURRENT_STATE.md`
- `docs/engineering/AGENT_WORKFLOW.md`
- `docs/engineering/DEFINITION_OF_DONE.md`

## Architecture and current milestone

- `docs/architecture/SARI_SUPPLY_PRODUCTION_PLAN.md`
- `docs/superpowers/specs/2026-09-26-firebase-identity-tenant-auth-design.md`
- `docs/superpowers/plans/2026-09-26-firebase-identity-tenant-auth.md`
- `docs/superpowers/plans/2026-09-25-sarisupply-foundation.md`

## GitHub Actions

Actions was tested with a minimal smoke workflow, but GitHub returned `startup_failure` before allocating a runner. The failing workflows were removed so `main` is not left permanently red. Repository verification is therefore kept in local scripts first so the same commands can later become CI gates without duplicating engineering logic.
