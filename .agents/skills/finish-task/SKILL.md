---
name: finish-task
description: Perform final SariSupply completion checks before reporting a coding task done.
---

# Finish Task

1. Read `docs/engineering/DEFINITION_OF_DONE.md`.
2. Inspect the final diff for unrelated changes.
3. Run `bash tool/verify_harness.sh`.
4. Run Firebase-specific verification when backend behavior changed and the harness exists.
5. Confirm documentation/current state is still accurate.
6. Report what passed.
7. Report any unavailable or skipped gate explicitly.

Never report an unavailable gate as passing.
