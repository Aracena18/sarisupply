## Summary

Describe the smallest coherent change in this PR.

## Source of truth

- Requirement/spec:
- Current-state impact:

## Scope

- [ ] No unrelated refactor is included.
- [ ] No user-facing visual change is included unless explicitly approved.
- [ ] New dependencies, if any, are justified.

## Verification

- [ ] `bash tool/verify_fast.sh`
- [ ] `bash tool/verify_harness.sh`
- [ ] Firebase verification executed when backend behavior changed.
- [ ] Any unavailable gate is documented below rather than treated as a pass.

## Risk review

Check the items that apply:

- [ ] Authorization / tenant / branch scope
- [ ] Offline durability / sync / retry
- [ ] Idempotency / duplicate processing
- [ ] Money / inventory correctness
- [ ] Secrets / credentials
- [ ] UI / responsive / accessibility
- [ ] None of the above

## Independent review findings

Summarize findings from a review pass separate from implementation.

## Known limitations or deferred work

List only known limitations that remain intentionally out of scope.
