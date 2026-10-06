# Agent Workflow

Use this workflow for implementation work in SariSupply. The objective is to make agent behavior predictable, reviewable, and test-driven.

## 1. Discover

Before editing:

1. Read `AGENTS.md`.
2. Read `docs/engineering/CURRENT_STATE.md`.
3. Locate the approved specification or requirement for the task.
4. Inspect the existing implementation and relevant tests.
5. Identify the smallest set of files and boundaries affected.

Do not assume a plan checkbox is implementation truth.

## 2. Plan

For any non-trivial change, state:

- intended behavior;
- affected modules/files;
- contracts or invariants involved;
- tests that should prove the behavior;
- security/offline risks when applicable.

Prefer a vertical slice over separate broad "frontend" and "backend" rewrites.

## 3. Light contract or unit test first

When business/financial logic is non-trivial, define the contract or add the smallest useful unit test before implementation.
Avoid authoring heavy UI widget tests or emulator flows during feature building; maintain construction speed.

## 4. Implement

- Build clean, production-grade features according to specifications.
- Follow existing package boundaries.
- Reuse existing abstractions and design-system components.
- Do not refactor unrelated code.
- Do not add dependencies without concrete justification.
- Preserve approved security and offline invariants.

## 5. Light Verify

During feature building, verify quickly with static analysis and focused unit checks:

```bash
flutter analyze
```

or for fast package sanity:

```bash
bash tool/verify_fast.sh
```

User conducts hands-on manual verification of screens and user flows. Full harness verification (`tool/verify_harness.sh`) is reserved for post-feature acceptance.

## 6. Review

Review the implementation independently from the authoring pass.

Look for:

- requirement mismatch;
- hidden behavior changes;
- security/tenant leaks;
- offline durability mistakes;
- money arithmetic mistakes;
- unnecessary abstractions;
- cross-layer coupling;
- missing failure states;
- missing tests;
- unrelated changes.

Use the `review-change` skill when available.

## 7. Repair

Fix concrete findings. Do not broaden the scope while repairing.

Re-run focused verification after each meaningful repair.

## 8. Final verify

Before claiming completion:

```bash
bash tool/verify_harness.sh
```

If the change touches Firebase behavior, run the Firebase-specific verification path when present.

Then check the Definition of Done.

## Completion language

Do not say a feature is complete when only source code has been generated.

Report:

- what changed;
- what was verified;
- any gate that could not be executed;
- any remaining known limitation.
