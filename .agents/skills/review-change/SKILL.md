---
name: review-change
description: Independently review a SariSupply change for correctness, regressions, architecture, security, offline safety, testing, and unnecessary complexity.
---

# Review Change

Assume the change may contain defects. Review before rewriting.

Check, in order:

1. Requirement/spec mismatch.
2. Unauthorized or unrelated scope changes.
3. Architecture-boundary violations.
4. Tenant/branch/device authorization mistakes.
5. Offline durability and retry/idempotency mistakes.
6. Money/value correctness where applicable.
7. Error and failure-state behavior.
8. Missing or weakened tests.
9. New dependencies or abstractions without need.
10. UI regressions if UI was touched.

Report concrete findings with severity and evidence. Do not approve merely because tests are green.
