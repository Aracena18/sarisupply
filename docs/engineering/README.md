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
- `AGENT_WORKFLOW.md` — standard workflow for agent-driven changes.
- `DEFINITION_OF_DONE.md` — completion gates.
- `ARCHITECTURE_BOUNDARIES.md` — dependency and layering constraints.
- `TESTING_STRATEGY.md` — test layers and expectations.
- `SECURITY_GATES.md` — security checks for sensitive work.
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
