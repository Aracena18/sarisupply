# SariSupply Engineering Index

This directory coordinates how SariSupply is built, reviewed, and verified. It does not replace product specifications or milestone implementation plans.

## Source-of-truth model

SariSupply separates three kinds of engineering information:

- **Specification** — what the approved system should do.
- **Implementation plan** — how a milestone is intended to be built.
- **Current state** — what is actually present in the repository now.

An agent must inspect current code before assuming a plan checkbox reflects implementation state.

## Core engineering documents

- `CURRENT_STATE.md` — current implementation status and active milestone.
- `../../design.md` — authoritative shared UI, UX, and copy contract.
- `UI_REDESIGN.md` — redesign behavior, deterministic screen evidence and verification limits.
- `AGENT_WORKFLOW.md` — standard workflow for agent-driven changes.
- `DEFINITION_OF_DONE.md` — completion gates.
- `ARCHITECTURE_BOUNDARIES.md` — dependency and layering constraints.
- `TESTING_STRATEGY.md` — test layers and expectations.
- `SECURITY_GATES.md` — security checks for sensitive work.
- `FIREBASE_FUNCTIONS_DEPENDENCY_TRIAGE.md` — current npm advisory assessment and dispositions.
- `HANDOFF_PHASE_4.md` — detailed coding-agent prompt and unfinished Phase 4 acceptance checkpoint.
- `PHONE_CHECKOUT.md` — phone scanning, cash/manual QR, shift recovery and capacity limits.
- `CATALOG_STOCK.md` — catalog, opening/count workflow, SQLite/sync contracts and limits.
- `FREE_BACKEND.md` — HTTPS backend configuration, free deployment and feasibility gate.
- `FREE_CAPACITY_PROFILE.json` — measured capacity worksheet; missing evidence fails closed.
- `TOOLCHAIN.md` — supported deterministic Flutter/Dart/Node versions.
- `CI.md` — CI activation and merge strategy.

## Repository-owned agent skills

Portable Agent Skills live under `.agents/skills/`:

- `implement-feature`
- `review-change`
- `flutter-quality`
- `firebase-security-review`
- `offline-first-review`
- `finish-task`

Agents may load only the skill relevant to the current task.

## Product and architecture

- `../architecture/SARI_SUPPLY_PRODUCTION_PLAN.md`

## Current milestone references

- Approved full platform scope: `../superpowers/specs/2026-10-04-free-production-platform.md`
- Active Phase 1 plan: `../superpowers/plans/2026-10-04-free-backend.md`
- Phase 2 scope: `../superpowers/specs/2026-10-04-identity-workspace.md`
- Phase 3 scope: `../superpowers/specs/2026-10-04-catalog-stock.md`
- Active Phase 3 plan: `../superpowers/plans/2026-10-04-catalog-stock.md`
- Approved Phase 4 phone checkout design: `../superpowers/specs/2026-10-04-phone-checkout.md`
- Active Phase 4 implementation plan: `../superpowers/plans/2026-10-05-phone-checkout.md`
- Active Phase 2 plan: `../superpowers/plans/2026-10-04-identity-workspace.md`
- Design: `../superpowers/specs/2026-09-26-firebase-identity-tenant-auth-design.md`
- Plan: `../superpowers/plans/2026-09-26-firebase-identity-tenant-auth.md`

## Repository verification

Fast feedback while working:

```bash
bash tool/verify_fast.sh
```

Full repository verification before completion:

```bash
bash tool/verify_harness.sh
```

The engineering logic belongs in repository scripts so local development, coding agents, and future CI use the same commands.
