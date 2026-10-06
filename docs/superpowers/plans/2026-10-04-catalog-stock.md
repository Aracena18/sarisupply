# Phase 3 implementation plan

Spec: `docs/superpowers/specs/2026-10-04-catalog-stock.md`

Global constraints: free services only; preserve dirty prior phases; no checkout
or unrelated refactors; no deployment; retain local business records on revocation.

- [x] 1. Define catalog/stock/sync domain contracts and SQLite persistence. Add
  failing tests for migration/reopen, atomic rollback, search/barcode and bounded
  sync cursor/ACK handling; implement and run focused tests.
- [x] 2. Add transactional catalog/stock commands and bounded delta reads. Add
  failing emulator tests for authority, uniqueness, retry, concurrent openings,
  count conflicts and negative stock; implement dispatcher integration.
- [x] 3. Wire typed HTTPS adapters, owner catalog/stock management and cashier
  inventory views. Add failing widget/adapter tests for recovery, unit forms,
  role controls and scope. Implement with existing theme and concise copy.
- [x] 4. Fast verification, documentation, final harness, one fresh independent
  review and one tested repair pass if needed; final full harness.

Interfaces: contracts in models; SQLite adapter in inventory package; Firebase
adapter consumes contracts; POS composes both. Changes carry monotonically
increasing revisions and stable operation IDs. No pending count is erased.

Review focus: lost ACK vs replay, count conflicts from another device, product
archive/update races, barcode reassignment, revoked readers/writers, new-device
bootstrap paging, response bounds, SQLite error/reopen and idle offline UI.

Expected focused commands: Flutter tests in models/inventory/POS/Firebase; Node 22
Firebase emulator verification. Expected final: `bash tool/verify_harness.sh` exits
0. Live gates remain explicitly unverified. Keep changes uncommitted for review.
