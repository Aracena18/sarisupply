---
name: firebase-security-review
description: Review SariSupply Firebase authentication, Firestore, Cloud Functions, device, tenancy, and cashier-credential changes for security invariants and emulator-test coverage.
---

# Firebase Security Review

Verify:

- privileged writes go through trusted server-side logic;
- current server state is checked for sensitive authorization;
- role/merchant/branch/device authority is not trusted from client input alone;
- Firestore/Storage rules remain deny-by-default except deliberate read/write paths;
- cross-tenant and cross-branch negative tests exist;
- revocation is enforced after reconnect/current server check;
- retryable privileged mutations are idempotent;
- secrets are not committed;
- emulator tests never target Production;
- cashier PIN plaintext is never persisted.
