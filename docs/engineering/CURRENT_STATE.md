# SariSupply Current State

**Last reviewed:** 2026-10-01

This document describes implementation reality. Update it when a milestone materially changes state.

## Product stage

SariSupply is in early production-foundation development. The approved direction is a Flutter-only client architecture with POS, Driver, and Admin applications, shared Dart/Flutter packages, Firebase cloud services, and a future Drift/SQLite offline transaction layer.

## Main branch

`main` currently contains the Flutter monorepo foundation, shared packages, basic tests, architecture documentation, and the approved Firebase identity design and implementation plan.

Implemented on `main` includes:

- Melos-managed Flutter monorepo.
- POS, Driver, and Admin Flutter application scaffolds.
- Shared `sarisupply_core`, `sarisupply_models`, and `sarisupply_design_system` packages.
- Integer-centavo `Money` value object.
- Shared Material 3 theme foundation.
- Local bootstrap and verification scripts.
- Firebase identity/tenant/device/cashier design specification.
- Detailed Firebase identity implementation plan.

## Active identity implementation branch

At the time this harness was introduced, `feat/firebase-identity-tenant-auth` contains partial implementation of Task 1 from the Firebase identity plan.

Observed there:

- `sarisupply_auth` and `sarisupply_firebase` package scaffolding.
- Firebase workspace scaffolding.
- Node.js 22 Functions project scaffold.
- deny-by-default Firestore and Storage rules.
- Firebase emulator configuration.
- DEV/PROD Android flavors for POS and Driver.
- Firebase environment parsing and a corresponding test.

Tasks 2–11 from the identity implementation plan are not yet represented by their planned production structures.

## Important distinction

The Firebase identity design is approved architecture.

The Firebase identity implementation plan is a blueprint.

Neither document alone proves that a feature is implemented. Agents must inspect the active branch and tests before reporting status.

## Current engineering-harness milestone

The harness milestone introduces:

- repository-level agent instructions;
- engineering source-of-truth documentation;
- reusable agent workflows;
- mechanical architecture checks;
- fast and full verification entry points;
- CI-ready repository commands.

This milestone must not change user-facing UI or product behavior.
