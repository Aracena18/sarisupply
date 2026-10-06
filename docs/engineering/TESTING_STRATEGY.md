# Testing Strategy

SariSupply uses layered tests. The fastest deterministic layer should catch most mistakes; higher layers prove integration and user journeys.

## Building Phase vs. Post-Implementation Testing Phase

To maintain velocity while ensuring software robustness:
- **During Feature Implementation (Build-Focused Mode)**:
  - Tests are intentionally kept **lightweight**. Focus is on construction: models, database operations, business logic, responsive phone UI screens, and user interaction handlers.
  - Verification during this phase emphasizes Layer 1 (static analysis, formatting, type safety) and focused Layer 2 unit tests for critical business/financial calculations.
  - The developer/user conducts manual testing and hands-on validation of features during the phases.
  - Layer 3 (heavy widget pump matrices), Layer 4 (emulator suites), and Layer 5 (end-to-end integration flows) are minimized to prevent slow test cycles and fake-async timeouts.
- **Post-Implementation Phase (Heavy Testing)**:
  - Once all production features are built across all phases, the repository undergoes full heavy testing: comprehensive regression suites, full emulator backend verification, and end-to-end acceptance harness runs (`tool/verify_harness.sh`).

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
