# Testing Strategy

SariSupply uses layered tests. The fastest deterministic layer should catch most mistakes; higher layers prove integration and user journeys.

## Layer 1 — static verification

- Dart formatting
- Flutter/Dart analysis
- architecture boundary checks

Run continuously during implementation.

## Layer 2 — pure/unit tests

Use for:

- money/value objects;
- authorization policies;
- state transitions;
- retry/idempotency helpers;
- offline credential policies;
- deterministic sync decisions.

Prefer pure Dart for logic that does not require Flutter.

## Layer 3 — Flutter widget tests

Use for:

- application gate states;
- validation;
- error/empty/loading states;
- critical user interactions;
- responsive behavior where practical.

Infrastructure-only harness changes must not rewrite UI merely to create tests.

## Layer 4 — backend/emulator tests

Use Firebase emulators for:

- Firestore Security Rules;
- callable Function authorization;
- tenancy and branch enforcement;
- device revocation;
- cashier credentials;
- idempotency;
- negative authorization scenarios.

Tests must never target Production.

## Layer 5 — acceptance/integration scenarios

Cover complete critical journeys such as:

```text
owner onboarding
-> approval
-> device activation
-> cashier setup
-> online credential enrollment
-> offline authentication
```

and negative journeys such as revocation, wrong-tenant access, and duplicate request processing.

## Future UI quality layer

When production screens are established, add golden/visual regression and accessibility checks before broad UI expansion. Capture approved appearance before intentional redesign work.

## Test integrity

- Never remove a valid test only because implementation fails it.
- Never replace meaningful assertions with weaker ones to get a green build.
- A skipped test is not a pass.
- A test for one layer does not replace a required test at another boundary.
