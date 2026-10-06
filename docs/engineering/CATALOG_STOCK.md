# Catalog and stock operations

Phase 3 local implementation: `docs/superpowers/specs/2026-10-04-catalog-stock.md`.
Use the existing HTTPS backend configuration in `FREE_BACKEND.md`. No service
requires billing; live deployment/account/capacity acceptance remains pending.

## Daily workflow

1. On the activated POS lock screen, choose **Manage store**, sign in, then open
   **Catalog and stock** and select an accessible branch.
2. **Sync** loads at most 250 catalog and 250 stock changes per action. Repeat
   while **Sync pending** remains. A new location may need several actions.
3. Owners add products: unique SKU, base unit, PHP selling price and optional
   barcode. Add packs/cases with an integral base-unit conversion and their own
   selling price/barcode. SKU/base unit cannot change after creation. Archive
   through **Available for sale**; the **Archived** filter allows restoration.
4. Owners/scoped managers record opening stock once per product/location. Later
   **Record count** records a physical quantity and mandatory reason. Counts save
   locally even without connectivity; choose **Sync** after recording a batch.
   Accepted counts may need another sync to receive the authoritative snapshot.
5. Conflicts/blocked counts remain listed. **Withdraw** appends a local reversal;
   sync, inspect the current stock, then enter a new count. Pending/accepted
   counts cannot be withdrawn while the server result is uncertain.
6. Cashiers can open saved inventory after PIN sign-in, search by name/SKU/barcode,
   view every sale-unit price and filter shortages. Their sync reads do not upload
   owner drafts. Checkout is now their primary task; see `PHONE_CHECKOUT.md` for scanning, payments and receipts.

No catalog is seeded automatically. Catalog edits require connectivity. Counts
are local drafts until accepted under current human branch authority. A cached
membership never grants server access. Local records survive sign-out/revocation;
only explicitly rejected drafts can be withdrawn. Device revoke/reconnect retains
business files while existing identity logic removes cached authorization.

## Persistence and transport

`packages/sarisupply_models`: pure contracts/validation, integer centavos and base
unit quantities. `packages/sarisupply_inventory`: SQLite adapter/sync; schema v1
plus tested v2 migration/backfill/indexes and immutable-ledger triggers. Schema v3
adds durable feed backlog state, supporting both earlier v2 variants without
resetting existing flags, cursors, pending operations or history. Phase 4 extends this same database through v5 for checkout and receipt recovery.
`packages/sarisupply_firebase`: typed `InventoryFunctions` HTTPS adapter.
`apps/pos`: sqflite Android composition and management/cashier views.

SQLite files are under Android's application database directory, scoped by encoded
merchant/branch and bound again in context metadata. Transactions use full
synchronous durability, foreign keys, and atomic movement/outbox or feed/cursor
updates. No PINs, credential hashes or tokens enter these files. Test-only FFI
opens real SQLite files for restart, migration and rollback evidence.

New dependencies have narrow purposes: `sqflite_common` abstracts SQLite access;
`sqflite` supplies the supported Android plugin; `sqflite_common_ffi` is test-only
for real-file tests on the development host. Primary package guidance:
[sqflite](https://pub.dev/packages/sqflite),
[FFI testing](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/testing.md).

Server commands: `saveCatalogProduct`, `recordStockCount`, `pullInventory`.
Owner-only catalog writes, live human branch-authorized counts, and device reads
check current authoritative records in Firestore transactions. Devices cannot
select a different tenant/branch. Clients have no direct rules access to catalog,
registry, stock, feed or operation records.

Catalog and stock each have a transactional sequence counter and append-only
change feed (50 rows/page). Mutation retries retain payload fingerprints and
operation results; accepted stock retries return duplicate. Local ACK before delta
and delta before ACK converge without double-counting. Catalog prices/units update
without altering ledger history. Stock conflicts never advance server stock.

## Capacity and release limits

No polling/listeners. Each sync is capped at five pages/feed and twenty uploads;
remaining work remains durable. Cloud data is capped at 3,000 product IDs per
merchant, including archived IDs. An accepted count writes four documents; a new
product writes five plus its barcode reservations (updates may release/add
reservations). Authorization, feed metadata, retries and receipts add reads.
A cold bootstrap of 3,000 products on ten POS devices consumes at least 30,000
product-change reads before stock/auth reads. Stage initial-device setup; do not
assume simultaneous cold bootstrap fits the 40,000-read engineering budget.

Append-only feed/receipt history still needs Phase 8 archival/retention. No cloud
history is deleted or reset now; a gapped feed fails closed. Capacity observations
remain unset until realistic measurements include catalog bootstraps, barcode
indexes, count volume, other platform phases and ninety-day retention. No live
Firestore quota guarantee or production certification is implied.

Local search caps visible results at 50 and uses escaped parameters. Real phone
latency, camera/hardware scanning, disk/power-loss faults and cross-device live
network/App Check checks remain external acceptance. The harness covers real-file
restart/transaction errors, emulator authority/rules and all supported app builds.
