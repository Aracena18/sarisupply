# Definition of Done

A SariSupply change is complete only when all applicable gates below are satisfied.

## Requirement gates

- The implemented behavior matches the approved requirement/specification.
- No unrelated behavior was intentionally changed.
- Deferred scope remains deferred.
- Current-state documentation is updated when milestone state materially changes.

## Code-quality gates

- Formatting passes.
- Static analysis passes.
- Architecture-boundary checks pass.
- No debug-only workaround, ignored failure, or unexplained TODO was introduced.
- New dependencies have a concrete justification and are added at the narrowest appropriate layer.

## Test gates

- Existing relevant tests still pass.
- New or changed behavior has appropriate tests.
- Security-sensitive behavior has negative-path tests where applicable.
- Offline behavior is tested across failure/retry boundaries when applicable.
- Firebase emulator/rules/function tests pass for affected backend behavior when that harness exists.

## Build gates

- Affected applications/packages build successfully using repository-supported commands.
- Environment selection is explicit where required.
- Production credentials or secrets are never needed for ordinary verification.

## Security gates

For authentication, authorization, tenancy, devices, cashier credentials, payments, or privileged operations:

- authorization is enforced server-side;
- tenant/branch/device context is not trusted solely from client input;
- sensitive data is not persisted in plaintext;
- retryable operations are idempotent where duplication is dangerous;
- deny-by-default boundaries remain intact.

See `SECURITY_GATES.md`.

## UI gates

For UI changes only:

- existing design-system components are reused when suitable;
- loading, empty, error, disabled, and success states are considered where relevant;
- responsive behavior is checked for the target form factors;
- accessibility is not knowingly regressed;
- visual design is not changed by infrastructure-only tasks.

## Final command

Before completion, run:

```bash
bash tool/verify_harness.sh
```

If a required gate cannot run because infrastructure is unavailable, report that explicitly rather than treating it as a pass.
