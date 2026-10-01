---
name: implement-feature
description: Implement a SariSupply feature or engineering change using the repository's spec-driven, test-gated workflow. Use for non-trivial code changes.
---

# Implement Feature

1. Read `AGENTS.md` and `docs/engineering/CURRENT_STATE.md`.
2. Locate the authoritative requirement/specification.
3. Inspect existing code and tests before editing.
4. State the smallest coherent implementation scope.
5. Identify affected architecture/security/offline invariants.
6. Add or update focused tests/contracts before implementation when practical.
7. Implement only the requested slice.
8. Run `bash tool/verify_fast.sh`.
9. Review the diff for unrelated changes and unnecessary dependencies.
10. Run `bash tool/verify_harness.sh` before declaring completion.
11. Report any verification gate that could not run.

Do not redesign UI unless the task explicitly authorizes visual changes.
