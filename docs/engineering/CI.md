# Continuous Integration Strategy

## Principle

CI is an execution environment, not the source of engineering rules.

The source of truth is:

```bash
bash tool/verify_harness.sh
```

Local development, coding agents, and future CI should run the same repository-owned checks.

## Current repository constraint

Previous GitHub Actions attempts returned `startup_failure` before a runner/job was allocated. Because that failure was infrastructure/account-side rather than a test failure, no active workflow is enabled by this harness milestone.

This prevents false permanent-red status while preserving a ready migration path.

## Activation sequence

When GitHub Actions is available:

1. copy `docs/engineering/github-actions-verify.example.yml` to `.github/workflows/verify.yml`;
2. run it manually or on a temporary PR;
3. confirm toolchain setup matches `TOOLCHAIN.md`;
4. confirm `tool/verify_harness.sh` passes;
5. make the verification check required for merge when repository settings permit it.

## Merge model

Preferred future flow:

```text
approved requirement/spec
        -> feature branch
        -> implementation + focused tests
        -> local verify_fast
        -> independent review
        -> local verify_harness
        -> pull request
        -> CI verify_harness
        -> merge
```

## CI must not

- contain unique tests that cannot be run locally;
- use a different Flutter/Dart toolchain;
- target Production Firebase for verification;
- silently skip required tests;
- hide failing commands behind `continue-on-error`.
