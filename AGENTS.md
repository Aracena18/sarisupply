# SariSupply Agent Guide

SariSupply is an offline-first retail operating system and distribution platform built with Flutter clients and a Firebase backend direction.

This file is the repository entry point for coding agents. Keep it short. Follow links to deeper documentation only when the current task needs them.

## Start here

- Product and production architecture: `docs/architecture/SARI_SUPPLY_PRODUCTION_PLAN.md`
- Engineering documentation index: `docs/engineering/README.md`
- Current repository state: `docs/engineering/CURRENT_STATE.md`
- Current Firebase identity design: `docs/superpowers/specs/2026-09-26-firebase-identity-tenant-auth-design.md`
- Current Firebase identity implementation plan: `docs/superpowers/plans/2026-09-26-firebase-identity-tenant-auth.md`
- Definition of done: `docs/engineering/DEFINITION_OF_DONE.md`
- Agent workflow: `docs/engineering/AGENT_WORKFLOW.md`

## Context rule

Read only the documentation needed for the task. Do not load every plan and specification by default.

Use this priority when sources disagree:

1. Explicit current task requirements.
2. Approved design/specification for the affected milestone.
3. `docs/engineering/CURRENT_STATE.md` for what is actually implemented.
4. Architecture documentation.
5. Existing implementation.

Never treat an unchecked implementation-plan item as proof that code is absent. Inspect the repository first.

## Repository boundaries

- User-facing applications live under `apps/pos`, `apps/admin`, and `apps/driver`.
- Shared code lives under `packages/`.
- Applications may depend on shared packages.
- Applications must not depend directly on another application.
- Shared packages must not import application code.
- Firebase-specific adapters belong in Firebase/infrastructure packages, not pure domain policy code.
- Do not introduce a new dependency without a concrete need and a justification.

See `docs/engineering/ARCHITECTURE_BOUNDARIES.md`.

## Change discipline

- Make the smallest coherent change that satisfies the approved requirement.
- Do not refactor unrelated code while implementing a feature.
- Do not rename unrelated APIs.
- Do not add abstractions for hypothetical future use.
- Do not redesign user-facing UI unless the task explicitly authorizes a design change.
- Preserve offline data and security invariants described in approved specifications.

## Verification

During implementation, prefer:

```bash
bash tool/verify_fast.sh
```

Before declaring a task complete, run:

```bash
bash tool/verify_harness.sh
```

If a task affects Firebase backend behavior, also run the Firebase verification path defined by the harness once that workspace exists.

## Agent workflow

Use the repository workflow:

```text
discover -> plan -> test/contract -> implement -> verify -> review -> repair -> final verify
```

Do not claim completion merely because code was generated.

## UI constraint for harness work

Engineering-harness changes must not alter the visible POS, Admin, or Driver experience. Harness work may inspect and test UI code, but visual changes belong to a separately approved design milestone.
