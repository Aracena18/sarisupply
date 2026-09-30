---
name: offline-first-review
description: Review SariSupply offline-first POS changes for local durability, atomicity, outbox behavior, retry safety, conflict handling, and reconnect authorization.
---

# Offline-First Review

Check the distinction between local durability and cloud synchronization.

For locally successful operations:

- required records commit atomically;
- outbox state is durable;
- immutable operation IDs exist before upload;
- retryable failures do not duplicate business effects;
- permanent authorization failures become blocked rather than infinite retries;
- reconnect/revocation does not erase unsynced local data;
- UI does not claim a durable local sale failed merely because cloud sync failed.

Require explicit tests for failure, retry, reconnect, and duplicate submission paths.
