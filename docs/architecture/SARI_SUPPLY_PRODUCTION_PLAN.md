# SariSupply Production Architecture

The [Canonical System Architecture](SYSTEM_ARCHITECTURE.md) is authoritative for
business ownership, roles, permissions, workflow ownership, and system invariants.
Read it first. This document retains the production roadmap and technical
direction; [Current State](../engineering/CURRENT_STATE.md) records implementation
status. Earlier milestone wording must be interpreted consistently with the
canonical contract.

## Product direction

SariSupply is a production-oriented retail operating system and distribution platform for medium-sized sari-sari stores. The POS is the operational entry point; the recurring business model is supplying and delivering store inventory.

One supplying company serves independent store businesses. Company Operations
owns warehouse fulfillment and rider dispatch; each Store Owner owns their retail
operations and confirms purchases. Store customers are not company branches.
Company and Platform Admin authority remain separate, even when held by one human.

## Flutter-only client strategy

All user-facing applications are implemented in Flutter:

- SariSupply POS — Flutter Android, phone-first and offline-first
- SariSupply Driver — Flutter Android
- SariSupply Admin / Operations — Flutter Web and existing Android support; separate authorized Company Operations and Platform Admin workspaces are the target

No React, Next.js, or separate non-Flutter frontend is part of the approved architecture.

## Backend and local data

- Firebase Authentication with Google Sign-In for Owner/Manager and administrative accounts
- Cloud Firestore as cloud source of truth
- Deno Deploy Free for privileged server-side computation against Firestore,
  subject to runtime, account eligibility and measured capacity gates
- Eligible free FCM, App Check, Crashlytics and Firebase Hosting services
- Firebase Spark only; no linked billing, deployed Cloud Functions, Secret
  Manager, Cloud Storage, paid backups or second cloud database
- Drift/SQLite for durable offline POS transactions and local projections

## Confirmed production capabilities

The roadmap includes multi-device and multi-branch POS, cashier PIN switching, product catalog and suggested pricing, multi-unit inventory, inventory ledger, offline synchronization, controlled negative inventory reconciliation, stock counts, batches and expiry, cash shifts, optional printing, Scan-to-Pay, refunds and voids, customer credit/utang, smart restocking with Store Owner purchase confirmation and company order acceptance, multi-warehouse inventory, procurement, fulfillment, hybrid delivery, separate Flutter Driver app, Flutter Admin / Operations, promotions, reporting, and tax-ready internal receipts. These are roadmap capabilities, not a claim that all are implemented.

## Engineering direction

The repository is a Melos-managed Flutter/Dart monorepo using Riverpod and feature-first architecture. Shared code lives in focused packages. Applications never import one another directly.

Implementation proceeds vertically: foundation, identity/tenant/device setup, offline POS and synchronization, then warehouse, fulfillment, delivery, and reporting.

## Identity milestone verification

`bash tool/verify_local.sh` checks the Flutter workspace and builds the
Development Admin web app and Android POS and Driver APKs. Add `--firebase` to
also run the backend TypeScript build, unit tests, Firestore rules tests, and
identity acceptance tests against a local demo project. The backend checks can
also be run alone with `bash tool/verify_firebase.sh`.

The approved [free production scope](../superpowers/specs/2026-10-04-free-production-platform.md)
supersedes the earlier billing-dependent deployment direction. Prepare the HTTPS
backend and server-only credentials using [FREE_BACKEND.md](../engineering/FREE_BACKEND.md).
Keep Firebase on Spark. An existing Firebase Auth user still needs the SariSupply
Admin role. Live account, attestation, capacity and device acceptance are required
before moving beyond Phase 1. No real-world pilot starts before all platform
milestones pass. Production deployment needs release approval and verification.

## Local checkout milestone

The user authorized local Phases 2–4 while hosted acceptance remains pending. Phase 4 shares one scoped SQLite database for catalog, stock, financial facts and outbox, with migrations through v5. Phone rear-camera scanning/manual fallback, local cash/manual QR receipts and shifts use pure shared policies and trusted HTTPS reconciliation. Grant secrets stay in encrypted device storage and server hashes; historical receipt intent contains a reference only. See [PHONE_CHECKOUT.md](../engineering/PHONE_CHECKOUT.md). This sequencing exception does not authorize deployment or a full-platform pilot.
