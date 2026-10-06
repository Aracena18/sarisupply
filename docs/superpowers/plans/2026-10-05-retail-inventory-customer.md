# Implementation Plan: Phase 5 Retail Inventory and Customer Transactions

User approved full-platform scope `2026-10-04-free-production-platform.md` and Phase 5 execution on 2026-10-05.
Native execution, one task at a time, test-gated with SQLite schema v6, HTTPS backend commands, pure models, and phone UI.

## Work Packages & Tasks

### Task 1: Extended Stock Movements, Transfers & Expiry Domain & SQLite Schema v6

**Files:**
- Create `packages/sarisupply_models/lib/src/inventory/stock_movement.dart`
- Create `packages/sarisupply_models/lib/src/inventory/batch_expiry.dart`
- Create `packages/sarisupply_models/lib/src/inventory/stock_transfer.dart`
- Modify `packages/sarisupply_models/lib/sarisupply_models.dart`
- Modify `packages/sarisupply_inventory/lib/src/inventory_store.dart`
- Modify `packages/sarisupply_inventory/lib/sarisupply_inventory.dart`
- Tests: `packages/sarisupply_models/test/inventory_movement_test.dart`, `packages/sarisupply_inventory/test/inventory_store_v6_test.dart`

**Interfaces:**
- `StockMovementKind`: `opening`, `count`, `sale`, `receiving`, `adjustment`, `transferOut`, `transferIn`.
- `BatchExpiryRecord`: `productId`, `batchNumber`, `expiryDate`, `quantity`.
- `StockTransferIntent`: `id`, `sourceBranchId`, `destinationBranchId`, `items`, `status` (`draft`, `dispatched`, `received`, `cancelled`).
- SQLite v6 migration: adds `batches` table, `transfers` table, preserves all existing v1–v5 financial/inventory records.

- [x] Write failing unit tests for extended stock movement models, batch validation, transfer state machines, and v6 schema upgrade/rollback injection.
- [x] Run test suite to verify RED state.
- [x] Implement `StockMovementKind`, `BatchExpiryRecord`, and `StockTransferIntent` in `sarisupply_models`.
- [x] Implement SQLite schema version 6 in `packages/sarisupply_inventory/lib/src/inventory_store.dart` with backwards-compatible upgrade path and rollback safety.
- [x] Run focused test suites: verify GREEN state.

### Task 2: Refunds & Voids Domain, Compensating Ledger & Authorization

**Files:**
- Create `packages/sarisupply_models/lib/src/checkout/refund.dart`
- Modify `packages/sarisupply_models/lib/sarisupply_models.dart`
- Modify `packages/sarisupply_inventory/lib/src/checkout_store.dart`
- Tests: `packages/sarisupply_models/test/refund_test.dart`, `packages/sarisupply_inventory/test/refund_store_test.dart`

**Interfaces:**
- `RefundIntent`: `id`, `originalSaleId`, `lines` (`productId`, `quantity`, `refundCentavos`), `tenderKind`, `reason`, `authorizedByCashierId`.
- `VoidIntent`: `id`, `originalSaleId`, `shiftId`, `reason`.
- Atomic local commit: compensating stock delta, drawer cash subtraction, immutable refund receipt, outbox entry. Original receipt remains immutable.

- [x] Write failing tests for refund/void models, ceiling calculations (cannot refund more than purchased quantity/value), and atomic rollback in `checkout_store`.
- [x] Run test suite to verify RED state.
- [x] Implement `RefundIntent`, `VoidIntent`, and validation in `sarisupply_models`.
- [x] Implement `recordRefund` and `recordVoid` atomic transactions in `checkout_store.dart`.
- [x] Run focused tests: verify GREEN state.

### Task 3: Backend HTTPS Commands, Feeds & Cloud Reconciliation

**Files:**
- Create `firebase/functions/src/catalog/receiving-service.ts`
- Create `firebase/functions/src/catalog/transfer-service.ts`
- Create `firebase/functions/src/checkout/refund-service.ts`
- Modify `firebase/functions/src/https/commands.ts`
- Modify `packages/sarisupply_firebase/lib/src/functions/`
- Tests: `firebase/functions/test/catalog/receiving.emulator.test.ts`, `firebase/functions/test/checkout/refund.emulator.test.ts`

**Interfaces:**
- HTTPS commands: `recordReceiving`, `recordStockAdjustment`, `initiateBranchTransfer`, `receiveBranchTransfer`, `recordRefund`, `voidSale`.
- Server verifies tenant/branch scope, active roles, current cashier assignment, and ensures two-phase branch transfers do not duplicate stock.
- Emits atomic multi-position feed events.

- [ ] Write failing emulator tests for backend receiving, transfer stages, refund limits, and concurrent transfer receipt.
- [ ] Run emulator tests to verify RED state.
- [ ] Implement backend services in `firebase/functions/src/` and wire into command registry.
- [ ] Implement client adapters in `packages/sarisupply_firebase`.
- [ ] Run Firebase emulator tests and verify GREEN state.

### Task 4: Promotion Rules & Customer Credit Ledger

**Files:**
- Create `packages/sarisupply_models/lib/src/checkout/promotion.dart`
- Create `packages/sarisupply_models/lib/src/checkout/customer_credit.dart`
- Modify `packages/sarisupply_models/lib/sarisupply_models.dart`
- Modify `packages/sarisupply_inventory/lib/src/checkout_store.dart`
- Tests: `packages/sarisupply_models/test/promotion_test.dart`, `packages/sarisupply_models/test/customer_credit_test.dart`

**Interfaces:**
- `PromotionRule`: `id`, `name`, `type` (`percentage`, `fixedAmount`, `bundleQty`), `minimumQuantity`, `discountValueCentavos`. Exact integer centavo math only.
- `CustomerAccount`: `id`, `name`, `phone`, `creditLimitCentavos`, `balanceCentavos`.
- `CreditAllowanceGrant`: server-reserved allowance for device. Repayments queue offline and do not replenish allowance before server acceptance.

- [ ] Write failing tests for promotion evaluation (multi-buy, line-item discounts) and offline credit reservation/repayment bounds.
- [ ] Implement promotion calculation engine and customer credit contracts in `sarisupply_models`.
- [ ] Implement customer ledger and credit tender in `sarisupply_inventory`.
- [ ] Verify test suite passes with GREEN state.

### Task 5: Phone UI, Whole-Phase Review & Harness Acceptance

**Files:**
- Create `apps/pos/lib/features/inventory/presentation/receiving_screen.dart`
- Create `apps/pos/lib/features/inventory/presentation/adjustment_screen.dart`
- Create `apps/pos/lib/features/inventory/presentation/transfer_screen.dart`
- Create `apps/pos/lib/features/checkout/refund_screen.dart`
- Create `apps/pos/lib/features/checkout/customer_credit_screen.dart`
- Modify `apps/pos/lib/features/checkout/checkout_screen.dart`
- Modify `apps/pos/lib/features/checkout/payment_screen.dart`
- Tests in `apps/pos/test/features/`

**Interfaces:**
- Responsive phone UI with 320/390/600/1024/1280 screen sizes, 200% text scale, keyboard-safe form inputs, no decorative filler.
- Full verification: `tool/verify_harness.sh`, `git diff --check`, whole-change review, update `CURRENT_STATE.md` and documentation.

- [ ] Implement POS UI screens with injected controllers and test fixtures.
- [ ] Run all POS tests and verify responsive layouts.
- [ ] Run full engineering harness `tool/verify_harness.sh`.
- [ ] Complete whole-phase code review and update current state and progress ledger.
