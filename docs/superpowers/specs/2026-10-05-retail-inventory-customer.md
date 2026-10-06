# Phase 5: Retail Inventory and Customer Transactions

Status: Approved specification following master scope `2026-10-04-free-production-platform.md` and user authorization on 2026-10-05.

## Intent and Scope

Phase 5 completes core retail store operations beyond standard sale checkout:
1. **Store Receiving & Physical Adjustments**: Ingesting stock from suppliers or central sources into branch inventory, and reason-coded adjustments (spoilage, damage, physical shrinkage).
2. **Branch Transfers**: Safe two-phase stock movement between branches (`dispatched` -> `received`) without phantom stock or double subtraction.
3. **Batch and Expiry Tracking**: Associating incoming stock units with batch identifiers and expiration dates for perishable retail inventory.
4. **Authorized Refunds and Voids**: Compensating ledger entries for customer returns and same-shift transaction voids, preserving immutable original sale history.
5. **Exact Promotions Engine**: Pure integer centavo discount rules (percentage, fixed amount, bundle pricing) evaluated deterministically with complete receipt auditing.
6. **Customer Accounts & Credit**: Customer registry, server-allocated offline credit allowances per customer and device, credit checkout tender, and debt repayments.

## Constraints

- Firebase remains on the free Spark plan. No billing account, no Cloud Functions deployment, no Secret Manager, no second cloud database.
- Firestore is the single cloud source of truth; SQLite provides local durability.
- All monetary amounts use integer PHP centavos. All unit conversions and base quantities are integer-bounded.
- Zero floating-point arithmetic in discount or unit math.
- In accordance with the approved platform constraints:
  - Offline credit allowances are strictly server-reserved per customer and device.
  - An expired credit allowance cannot be reused without online server refresh.
  - Offline debt repayments queue locally and reduce local customer balance but do not replenish device credit allowance until acknowledged by the server.
- Phone-first responsive UI: 320px–390px portrait priority, 48px touch targets, no decorative filler, keyboard-safe layouts.

## Architecture Boundaries

- Domain policies, models, and calculation rules live in `packages/sarisupply_models`.
- SQLite storage, migrations, and offline queues live in `packages/sarisupply_inventory`.
- Firebase HTTPS adapters live in `packages/sarisupply_firebase`.
- Backend HTTPS command implementations and Firestore transactions live in `firebase/functions/src/`.
- UI features live in `apps/pos/lib/features/`.
