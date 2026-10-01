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

Domain value objects and records. Prefer keeping domain logic free from infrastructure concerns.

### sarisupply_design_system

Shared visual language and reusable Flutter UI primitives. It must not depend on an application.

### sarisupply_auth

Authentication/authorization contracts and pure access policies. Firebase-specific implementations do not belong here.

### sarisupply_firebase

Firebase adapters, bootstrap code, gateways, and infrastructure integration.

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

Privileged Firebase mutations belong in Cloud Functions/server code rather than direct client writes.

Firestore Security Rules are defense in depth, not the sole authorization mechanism.

## Architecture changes

If a task genuinely requires changing these boundaries:

1. document the reason;
2. update this file and the approved architecture;
3. update the architecture checker;
4. include focused tests.

Do not silently bypass a boundary.
