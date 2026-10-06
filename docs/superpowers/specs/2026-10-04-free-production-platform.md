# Full platform production scope

Approved in the implementation conversation on 2026-10-04. This specification
supersedes architecture assumptions requiring Firebase billing.

## Constraints

- Complete the full platform before any real-world pilot. Internal testing is allowed.
- Flutter POS on Android phones/tablets, Android Driver, Flutter Web Admin.
- Firebase remains Spark with no linked billing. Firestore is the only cloud
  database; Drift/SQLite provides local durability. No paid services, payment
  processing, Cloud Functions deployment, Secret Manager, Cloud Storage, or paid backups.
- Deno Deploy Free may run trusted computation against Firestore. No Deno KV or
  second cloud database. Verify runtime, account restrictions, quotas, and realistic
  load before accepting it. No automatic paid fallback or uptime guarantee.
- Cash and existing QR payments confirmed manually in the bank/wallet app.
  Record confirmation/reference; never claim provider verification.
- Target 1–5 stores, two POS devices/store, up to 200 receipts/store/day,
  3,000 SKUs/store, five receipt lines on average, PHP integer centavos.
- Keep existing seven-day same-boot offline authentication. Reboot needs one
  reconnect; operators have a backup hotspot. Preserve durable pending operations.
- Allow physical sales with insufficient cloud stock; reconcile negative balances.
- Reserve server-issued offline credit allowance per customer and device. Do not
  reuse allowance merely because it expires; reconcile pending operations first.
  Offline repayments do not replenish allowance before server acceptance.
- Retain 90 days of settled detailed online records. Retain unresolved operations
  and open balances longer. Archive encrypted files with manifests; prove restore
  and confirm two owner-controlled copies before deleting cloud records.

## Contracts

Reuse current identity authorization, tenant/branch isolation, PIN scrypt policy,
audits, and idempotency. HTTPS replaces the deployed callable transport while
retaining command names and response shapes. Verify Firebase Auth tokens,
deployment environment, App Check, and current server role/device state.
Keep service credentials and PIN pepper exclusively on the trusted server.

Local sale, tender, inventory changes, and outbox operation commit atomically.
Generate operation UUID before commit. Synchronization acknowledges accepted,
duplicate, conflict, or blocked outcomes; uncertain outcomes remain durable.
Finance records are immutable; refunds create compensating entries.

Engineering budgets: 40,000 Firestore reads/day, 16,000 writes/day, 750 MiB
including indexes and maintenance. Account for device bootstrap, transaction
retries, reporting, archival, and reconnect traffic. Use bounded delta sync and
pagination. Quota exhaustion retains local work and blocks server-required actions.

## Milestones and gates

1. Free trusted backend, HTTPS identity transport, security tests, realistic
   capacity accounting, and hosting feasibility. **Stop broader implementation if
   account/runtime/capacity feasibility cannot be demonstrated.** On 2026-10-04,
   after local Phase 1 verification, the user explicitly authorized local Phases 2 and 3
   work while hosted account/capacity evidence remains pending. This exception
   does not authorize deployment, a pilot or claiming hosted feasibility.
   The user subsequently authorized continuing to local Phase 4 on the same date,
   specifying phone-camera scanning and phone-focused interaction. The same live
   acceptance gates remain in force.
2. Practical Owner/Manager/Cashier enrollment, branch/device management and recovery;
   shared responsive Flutter UI foundations.
3. Catalog, barcodes, units/prices, opening stock, SQLite migrations, durable
   ledger/outbox, delta sync and shortage reconciliation.
4. Scan/search, cart, cash/manual QR, change, receipts, shift float/cash movements/closing.
5. Receiving, counts, adjustments, branch transfers, batch/expiry, refunds/voids,
   promotions, customers, credit and repayments.
6. Owner-approved restocking, suppliers/procurement, multiple warehouses,
   receiving/reservation/pick/pack.
7. Scoped dispatch and Driver stops; installed maps app; partial/failed delivery,
   returns and collection, including manual coordination when offline.
8. Ledger-consistent reports/exports, encrypted archives, printing and notifications.
9. Release signing, free hosting, monitoring, restore/migration checks, operator
   instructions, regression evidence and rollback before pilot.

## Product acceptance

Phone POS prioritizes scan/search/cart/payment; tablets support split catalog/cart.
Admin prioritizes actionable queues/search; Driver prioritizes stop actions.
Remove filler, fake statistics, development/beta labels and raw exception text.
Keep useful Offline/Saved/Sync pending/error recovery states. Graphics must serve a
task; no decorative asset requirement. Delivery proof uses recipient, quantities,
timestamp and structured metadata, without cloud photos.

Target trained cashier cash checkout under 60 seconds, local search under 200 ms,
durable checkout under one second on the agreed target hardware. Validate access
isolation, crash/restart/retry/partial acknowledgment, multi-POS stock and credit,
units/promotions/refunds, partial delivery, archive corruption/restore, quota
exhaustion and migrations. Test responsive UI, accessibility, cameras and actual
printers. Receipts are internal records, without a regulatory certification claim.

Implement one bounded milestone at a time with test/contract, verification,
independent review and repair. Do not label the whole platform production-ready
until every milestone and live hardware/deployment gate has evidence.
