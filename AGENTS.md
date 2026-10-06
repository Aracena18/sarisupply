# SariSupply Agent Guide

SariSupply is an offline-first retail operating system and distribution platform built with Flutter clients and a Firebase backend direction.

This file is the repository entry point for coding agents. Keep it short. Follow links to deeper documentation only when the current task needs them.

## Start here

Read `design.md` before changing UI, UX, or user-facing copy.

- Product and production architecture: `docs/architecture/SARI_SUPPLY_PRODUCTION_PLAN.md`
- Engineering documentation index: `docs/engineering/README.md`
- Current repository state: `docs/engineering/CURRENT_STATE.md`
- Approved free production scope: `docs/superpowers/specs/2026-10-04-free-production-platform.md`
- Active free-backend milestone: `docs/superpowers/plans/2026-10-04-free-backend.md`
- Active identity workspace: `docs/superpowers/plans/2026-10-04-identity-workspace.md`
- Active catalog/stock workspace: `docs/superpowers/plans/2026-10-04-catalog-stock.md`
- Approved phone checkout design: `docs/superpowers/specs/2026-10-04-phone-checkout.md`
- Active Phase 4 plan: `docs/superpowers/plans/2026-10-05-phone-checkout.md`
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

## Verification & Testing Approach (Build-Focused Mode)

To maximize building velocity across phases:
- **Agent role**: Responsible for rapid, high-quality building (clean domain logic, offline state, responsive phone UI screens, architectural boundaries, and zero compile/static analysis warnings).
- **Light testing during building**: Keep per-task automated testing light. Do not build heavy UI widget pump matrices, slow SQLite FFI async loops, or heavy integration test suites for every screen during construction.
- **Fast verification**: Rely primarily on static analysis (`flutter analyze` / `dart analyze`) and fast unit checks for critical business logic or financial calculations.
- **User manual testing**: The developer/user conducts hands-on manual verification and user flow testing during and between phases.
- **Heavy testing deferred**: Comprehensive end-to-end integration flows, full emulator suites, and heavy automated testing runs (`tool/verify_harness.sh`) are deferred until *after* all features across the production plan are implemented.

During implementation, verify with:

```bash
flutter analyze
```

or for fast package sanity:

```bash
bash tool/verify_fast.sh
```

## Agent workflow

Use the streamlined builder workflow:

```text
discover -> plan -> implement -> light verify (analyze/focused unit) -> review
```

Do not claim completion merely because code was generated. Ensure code compiles cleanly with zero static analysis warnings.

## Codex skills

Use available skills whenever their documented purpose matches the current task. Read the relevant `SKILL.md` before applying it; load only the skills needed. User-installed skills live under `$CODEX_HOME/skills` (default `~/.codex/skills`); repository skills live under `.agents/skills`.

- Use repository skills for implementation, Flutter quality, Firebase security, offline safety, review, and completion checks when applicable.
- Use `caveman` for concise routine updates and answers. Preserve technical facts, commands, paths, errors, and verification results; use fuller explanations when clarity or the user requires them. Honor "normal mode" or "stop caveman". Use `ultracave` and `megacave` only when explicitly requested.
- Use `caveman-commit`, `caveman-review`, `caveman-help`, and `caveman-stats` for their corresponding tasks. Terse review wording must preserve the repository review scope. Report usage or savings only when supported by measurements.
- Use `caveman-compress` only when the user requests file compression; preserve its backup and exact-code requirements.
- Use matching OmniRoute `omni-*` and `cli-*` skills for gateway authentication, models, routing, compression, diagnostics, or management. Use `config-codex-cli` when configuring Codex to connect to OmniRoute is part of the task. Confirm the required gateway or CLI is available before claiming an integration works.

Skill installation alone does not authorize changing Codex providers, credentials, gateway settings, or repository files outside the task. Skills must respect this guide's architecture, security, offline, UI, and verification requirements. If a skill is unavailable, state that briefly and continue with the repository workflow where possible.

## UI constraint for harness work

Engineering-harness changes must not alter the visible POS, Admin, or Driver experience. Harness work may inspect and test UI code, but visual changes belong to a separately approved design milestone.
