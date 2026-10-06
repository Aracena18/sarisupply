# Architecture Boundaries

These boundaries are intentionally simple and mechanically checkable.

## Top-level layers

```text
apps/*
  -> packages/*

packages/*
  -X-> apps/*
```

Applications may consume shared packages. Shared packages must never import application source.

## Application isolation

The three user-facing applications are independent clients:

- `apps/pos`
- `apps/admin`
- `apps/driver`

One application must never import source code from another application's `lib/` tree.

Shared behavior belongs in a focused package.

## Shared-package responsibilities

### sarisupply_core

Small cross-application primitives that do not belong to a specific business domain.

### sarisupply_models

Domain value objects, checkout/cart/money/shift policies and gateway contracts. Prefer keeping domain logic free from infrastructure concerns.

### sarisupply_design_system

Shared visual language and reusable Flutter UI primitives. It must not depend on an application.

### sarisupply_auth

Authentication/authorization contracts and pure access policies. Firebase-specific implementations do not belong here.

### sarisupply_inventory

SQLite catalog/stock/checkout persistence and bounded sync orchestration consuming pure
model contracts. No Firebase or application imports. Android composition belongs
to POS; real-file FFI is a test adapter. Financial facts, stock deltas, outbox and receipt recovery share one atomic database transaction. Migrations through v5 preserve earlier schemas. Cashier grant secrets belong in encrypted device storage, never this database.

### sarisupply_firebase

Firebase adapters, bootstrap code, gateways, and infrastructure integration. Transport supplies encrypted-store grant secrets separately from immutable checkout intent. Camera lifecycle and the POS-only scanner dependency belong in `apps/pos`.

## Dependency direction

Preferred direction:

```text
application
   -> contracts/domain
   -> infrastructure adapters where composition requires them

infrastructure
   -> domain/contracts

domain/contracts
   -X-> application
   -X-> Firebase implementation details
```

## Backend boundaries

Privileged Firestore mutations belong in the trusted HTTPS server rather than direct client writes. The Functions workspace also runs local emulator tests; production Cloud Functions deployment is excluded by the approved free scope.

Firestore Security Rules are defense in depth, not the sole authorization mechanism.

## Architecture changes

If a task genuinely requires changing these boundaries:

1. document the reason;
2. update this file and the approved architecture;
3. update the architecture checker;
4. include focused tests.

Do not silently bypass a boundary.
