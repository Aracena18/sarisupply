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

## Test gates (Phase-by-Phase Building vs. Post-Feature Heavy Testing)

During active feature implementation phases:
- Existing tests continue to pass without regression.
- Light unit tests are added only where essential for pure domain/financial calculation contracts.
- Heavy widget test suites, multi-breakpoint UI pumps, and emulator harness runs are minimized during per-task construction to maintain building velocity.
- The developer/user performs hands-on manual testing of screens and user flows during feature delivery.

During post-feature final acceptance (after all features are implemented):
- Comprehensive regression testing across all packages.
- Firebase emulator/rules/function tests pass for all backend behavior.
- Full automated verification harness is executed.

## Build gates

- Affected applications/packages build successfully using repository-supported commands.
- Static analysis passes with zero warnings or errors (`flutter analyze` / `dart analyze`).
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
- responsive behavior is checked for the target form factors (320px–390px phone portrait, 48px touch targets);
- accessibility is not knowingly regressed;
- visual design is not changed by infrastructure-only tasks.

## Verification Commands

- **Per-Task / During Building**:
  ```bash
  flutter analyze
  ```
- **Final Acceptance (Post-Feature Completion)**:
  ```bash
  bash tool/verify_harness.sh
  ```

If a required gate cannot run because infrastructure is unavailable, report that explicitly rather than treating it as a pass.
