# Phone Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete locally usable Android phone checkout with camera scanning,
cash/manual QR, offline receipts and cashier shifts.

**Architecture:** Reuse the merchant/branch SQLite database for atomic financial
and stock commits. Pure Dart contracts/policies stay in models; SQLite and HTTPS
adapters stay in their existing infrastructure packages. POS owns camera/lifecycle
and phone interaction; trusted commands own authorization and cloud reconciliation.

**Tech Stack:** Existing Flutter/Dart, sqflite/sqflite_common, secure storage,
Firebase Admin/Firestore and Deno-compatible HTTPS. Add `mobile_scanner` only to POS,
using its bundled Android model; resolve/pin a compatible version during Task 4.

**Spec:** `docs/superpowers/specs/2026-10-04-phone-checkout.md`, approved by the
user's “Proceed next” on 2026-10-05.

## Global Constraints

- Firebase stays on Spark with no billing account. No paid service or deployment.
- Phone rear camera only for this milestone; no tablet or external scanner required.
- Target 1–5 stores, two POS devices/store, up to 200 receipts/store/day,
  3,000 SKUs/store and five receipt lines on average.
- PHP integer centavos; 50 lines and 20 distinct products per receipt;
  receipt total at most 1,000,000,000 centavos. Integral sale-unit factors.
- Retain seven-day same-boot offline authentication; reboot/expiry requires reconnect.
- Sale, tender, stock movements, cash movement, outbox and draft completion commit
  atomically, using a UUID created before checkout. Finance records are append-only.
- Allow negative stock. Do not silently reprice a draft or alter historical receipts.
- Cash and manually confirmed QR only. No provider-verification claim or processing.
- Sync at most 20 checkout intents and five 50-event pages per feed per action.
- Keep 40,000 reads/day, 16,000 writes/day and 750 MiB engineering budgets unproven
  until measured. Preserve unresolved work and 90-day retention prerequisites.
- Preserve all dirty prior-phase/user work. Use the existing feature checkout;
  keep changes uncommitted for review. No automatic push, merge or release.
- Existing schema/navigation repairs are already implemented and verified. Inspect
  their tests; do not redo them merely because this plan starts a new milestone.

## Review Focus

- Several units of one SKU and concurrent POS sales: aggregate the correct base
  quantities, accept negative stock, and never double-subtract after ACK/feed replay.
- Process death between tender entry and receipt display: recover the existing
  sale UUID and draft; never ask the operator to collect the same payment again.
- An expired/replaced grant still referenced by pending work: keep the old secure
  secret available for reconciliation without granting a new offline session.
- A blocked opening/sale before close: retain dependent intents and the immutable
  local close; never claim that all cloud financial records settled.
- Real camera/lifecycle differences: repeated frames add one item, permission denial
  leaves search usable, and wallet switching resumes the same draft safely.

## Shared decisions

Use existing packages; do not introduce another shared package for this feature.
`packages/sarisupply_models/lib/src/checkout/` contains immutable contracts and
deterministic validation/calculation, with no Firebase/Flutter imports.

`InventoryStore` remains the database owner. Add a `CheckoutStore` facade sharing
its private connection through library-private composition (`part` files are
acceptable). Widgets must not receive raw database access. A new v4 migration
adds checkout tables, immutable-finance guards and product catalog-event provenance.
Keep existing count ledger/outbox intact.

Introduce `StockEvent(sequence, operationId, kind, positions)` and
`StockPosition(productId, quantity, revision, delta)`. Legacy single-product count
documents normalize to a count event; `delta` is nullable for those snapshots,
while sale positions require their negative base-unit delta. A sale event has
1–20 distinct positions.
`InventoryGateway.pullStock` and `InventoryStore.applyStock` consume
`DeltaPage<StockEvent>`; update every typed caller/test without weakening its
assertions. Retain the legacy `StockChange` constructor/parser as a normalization
helper if needed. The wire feed remains `pullInventory`, with one sequence per event.

Persist catalog event sequence alongside a product in v4. Existing rows initially
have unknown provenance and cannot become payable quotes until reconciled through
a bounded indexed lookup. Add `resolveCatalogQuotes` for at most 20 product/revision
pairs per call; query exact `product.id` and `product.revision` equalities with
`limit(2)` per pair to detect missing/duplicate history. Verify the returned snapshot
matches the cached quote and record its exact event sequence. Save resolved provenance
transactionally; retain it after restart. Resolve only products needed by the cart,
not the entire old cache. Include the required Firestore index in version control.
No unbounded scan/full bootstrap or invented event sequence is allowed. New catalog
pages set provenance as they apply. A current server price change requires explicit
cart review; a completed offline sale validates against its original historical quote.

Grant metadata/reference may enter SQLite; grant secrets may not. Store secrets by
device/grant ID in secure storage, separately from active login credentials, so
renewal cannot overwrite a pending intent's secret. Never allow that retained
secret to bypass a missing/revoked active session or trusted clock policy.

### Task 1: checkout policies and atomic local persistence

**Files:** Create model files `packages/sarisupply_models/lib/src/checkout/{cart,payment,shift,checkout_intent}.dart`;
export from `packages/sarisupply_models/lib/sarisupply_models.dart`.
Modify `packages/sarisupply_models/lib/src/inventory/catalog.dart` to add event
contracts; defer retyping the existing gateway/store methods until Task 3.
Create `packages/sarisupply_inventory/lib/src/checkout_store.dart`; modify
`inventory_store.dart` and package export. Tests:
`packages/sarisupply_models/test/checkout_test.dart`,
`packages/sarisupply_inventory/test/checkout_store_test.dart`,
`checkout_migration_test.dart`, and existing stock/sync/migration tests.

**Interfaces:** Produce `CartLine` (product/unit snapshots, catalog sequence and
revision, positive unit quantity), `CheckoutDraft`, `CheckoutSale`, `Tender`,
`CashierShift`, `CheckoutIntent`, `CheckoutAck`, `StockEvent` and `StockPosition`.
`CheckoutSale.totalCentavos`, `Tender.changeCentavos`,
`CashierShift.expectedCashCentavos` and `varianceCentavos` are integers.
Produce `InventoryStore.checkout: CheckoutStore`, with:
`saveDraft(CheckoutDraft)`, `readDraft(String deviceId, String cashierId)`,
`completeSale(CheckoutSale) -> Future<CheckoutSale>`,
`sale(String operationId) -> Future<CheckoutSale?>`,
`openShift(CheckoutIntent)`, `recordCashMovement(CheckoutIntent)`,
`closeShift(CheckoutIntent)`, `activeShift(String deviceId)`,
`pendingIntents({int limit = 20})`, `acknowledge(CheckoutAck)` and
`receipts({String query = '', String? cursor, int limit = 50})`.
All asynchronous methods return futures; mutations reject mismatched scope.

- [x] Write failing policy/file-backed tests. Pin these assertions:
  `expect(packLine.baseQuantity, 12)` for two six-piece packs;
  `expect(cashTender.changeCentavos, 750)` for total 1,250 and received 2,000;
  `expect(qrShift.expectedCashCentavos, openingFloat)`;
  `expect(() => unconfirmedQr.validate(), throwsArgumentError)`;
  reject overflow, insufficient cash, duplicate product/unit quote inconsistency,
  51 lines and 21 products. A zero-total sale uses cash with zero tender/change;
  reject zero-total QR rather than inventing receipt of funds. Validate multiplication
  before overflow; retain existing factor limits and at most 1,000,000,000 aggregate
  base units per product in one sale.
- [x] Run `flutter test test/checkout_test.dart` from models and
  `flutter test test/checkout_store_test.dart test/checkout_migration_test.dart`
  from inventory. Expected: new checkout behavior fails before implementation.
- [x] Implement v4 and the specified contracts/facade. Use separate immutable sale,
  tender, sale-stock and cash-entry tables plus mutable drafts/status/projections.
  Freeze the sale UUID/payload in its draft before commit. Group stock by product.
  Count overlays and subsequent pending sales compose in local append order.
  Exact UUID/payload replay returns the stored sale; mismatched reuse rejects.
- [x] Add rollback tests using independent SQLite failure triggers on each required
  write. Assert no sale/tender/movement/outbox/draft completion survives a failure;
  exact retry then creates one receipt. Cover file reopen, frozen UUID recovery,
  v1/v2/v3 upgrades, same-device shift uniqueness, cashier mismatch, closed shift,
  negative stock, count/sale ordering and immutable update/delete denial.
- [x] Run `flutter test` in models and inventory. Expected: both entire suites pass,
  including unchanged Phase 3 behavioral assertions. Record results in the ledger.

### Task 2: cashier grants and authorization at every financial write

**Files:** Create `firebase/functions/src/checkout/cashier-grants.ts` and grant
tests under `firebase/functions/test/checkout/`. Modify cashier service, existing
Auth repository/HTTPS cashier adapter, POS secure storage/login service/workflow
and their existing tests. Extend device bootstrap metadata in
`firebase/functions/src/device/device-service.ts`,
`packages/sarisupply_auth/lib/src/device_repository.dart` and Firebase adapter,
so receipts have real merchant/branch display names saved locally.

**Interfaces:** Produce `IssuedCashierGrant` (ID, secret, bound scope/version,
issued/expiry timestamps) via optional `CashierPinVerification.grant`.
Keep `CashierRepository.changePin -> Future<int>`: the existing change-PIN workflow
already calls online login with the new PIN; that verification issues the grant.
Produce secure `saveCheckoutGrant`, `readCheckoutGrant`, and active-session
`authorizeCheckout(CashierSession) -> Future<CheckoutAuthorization>` on `PosWorkflow`.
Authorization carries bound metadata/time evidence, not secrets for receipt storage.

- [x] Write failing emulator/client tests: successful permanent PIN verification
  issues a device/cashier/version-bound grant; wrong PIN, cooldown or mandatory
  temporary PIN yields no usable grant. Assert stored document has `secretHash`
  but no plaintext `secret`/PIN. Check seven-day maximum and tamper denial.
- [x] Run focused Flutter grant/login tests and, with Node 22 selected,
  `bash tool/verify_firebase.sh` from repository root. Expected: added grant
  contracts/behavior fail; emulator target remains `demo-sarisupply-rules`.
- [x] Generate a 32-byte random secret and independent grant ID before the PIN
  transaction; persist SHA-256(secret) and immutable binding inside it only on
  successful permanent verification. Grant expiry is at most seven days.
  Store/cache only after verifying bundle scope/version; consume a fresh grant
  after mandatory PIN change through the existing final online login.
- [x] Test active-session commit checks at expiry, reboot, missing clock evidence,
  changed credential version and sign-out/revocation. Assert no financial commit
  occurs and drafts/pending business records remain. Test grant renewal preserves
  older intent references and secret redaction from SQLite, errors and receipt JSON.
  Bootstrap display metadata is presentation only and cannot grant scope authority.
- [x] Run full POS/Auth/Firebase-adapter Flutter suites and Firebase verification.
  Expected: all pass, including existing attestation/offline identity regressions.

### Task 3: trusted checkout commands, atomic stock events and bounded sync

**Files:** Create `firebase/functions/src/checkout/{checkout-service,checkout-validation}.ts`,
`packages/sarisupply_firebase/lib/src/functions/checkout_functions.dart`,
`packages/sarisupply_inventory/lib/src/checkout_sync.dart` and their tests.
Modify `firebase/functions/src/https/commands.ts`, catalog service, Firestore
rules tests, `firebase/firestore.indexes.json`, runtime probe, existing inventory
contracts/store/sync/adapter and
stock-count tests. Add the command registry and adapter export entries.

**Interfaces:** Produce trusted `recordCheckoutOperation(db, request, input)`
and `resolveCatalogQuotes(db, request, input)` commands.
`CheckoutGateway.push(CheckoutIntent intent, IssuedCashierGrant grant)` returns
`Future<CheckoutAck>`; its envelope includes scope, grant ID/secret and immutable
intent separately. `CheckoutSync.run()` consumes store/gateway plus a secure grant
resolver; returns whether more/review work remains. Inventory sync pulls typed
atomic stock events for cashiers and humans alike.

- [x] Write failing emulator tests for open/sale/cash-in/cash-out/close, current
  authority, replay and concurrent devices. A five-product accepted sale must
  emit one stock event containing five positions, deduct all base quantities,
  persist one immutable financial envelope and update cash totals correctly.
  Assert exact replay changes no counters/stock; changed-payload reuse blocks.
- [x] Run `bash tool/verify_firebase.sh` with Node 22. Expected: checkout commands,
  quote provenance resolution and atomic-event cases fail before implementation.
- [x] Implement all reads before transaction writes. Recheck current device,
  merchant/branch, cashier assignment/status/version, grant hash/binding and
  original intent time window, including before idempotent replay. Verify quotes
  by padded exact catalog-event IDs and recompute totals/unit conversions.
  Device open/close checks the active shift; each accepted mutation advances its
  shift ordinal once. Accept stale-but-valid historical prices and negative stock.
  QR remains explicitly manual. Retain blocked/conflict receipts without finance
  effects, and keep transient failures retryable. No direct client Firestore access.
- [x] Implement v4-aware stock event normalization/application and checkout sync.
  Sale event validation matches local product deltas, not its resulting server
  quantity, which may reflect another POS. Entire positions/ACK/cursor apply atomically.
  Apply ACK immediately after each upload; stop on blocked/conflict dependencies.
  Non-sale ACKs need no stock sequence; sale ACKs require a valid matching sequence.
  A resolved event can settle a lost ACK; an unrelated consumed event cannot.
- [x] Add tests for malformed/gapped multi-product events, stale/foreign ACK,
  ACK-before-feed, feed-before-ACK, replay, partial acceptance then timeout,
  quota exhaustion, missing secure grant, retained close behind blocked sale,
  count/sale concurrency and 20-intent/five-page limits. Cashier sync never uploads
  owner count drafts. Deny cross-tenant/branch/device/cashier, revoked/version-changed
  and spoofed quotes; reconcile expired grants only for intents in their original window.
  Pin indexed historical lookup limits, missing/duplicate quote recovery and
  migration provenance after reopen.
- [x] Run inventory/Firebase-adapter Flutter suites and Firebase verification.
  Extend the Deno probe through grant issuance, checkout replay and sale-event pull.
  Expected: all suites and pinned runtime probe pass. Record measured operation counts.

### Task 4: phone search, camera, cart, payments, receipts and shifts

**Files:** Create POS `lib/features/checkout/{checkout_screen,barcode_scanner_screen,
payment_screen,receipt_screen,receipt_history_screen,shift_screen}.dart` and tests
`test/features/{checkout_screen,barcode_scanner_screen,payment_screen,shift_screen}_test.dart`.
Modify `pos_app_gate.dart`, `firebase_pos_workflow.dart`, `apps/pos/pubspec.yaml`,
lockfile and Android manifest if required by the scanner. Reuse the current theme.

**Interfaces:** `CheckoutScreen` consumes scoped store, inventory/checkout gateways,
session and `authorizeCheckout` callback. `BarcodeScannerScreen` returns one exact
barcode string or cancel. `PaymentScreen` edits the saved draft, authorizes then
completes one frozen sale intent. Receipt/history/shift screens use local contracts.
Inject a scanner boundary/controller into widget tests; production uses the camera
plugin, not fake detections. Preserve lifecycle and session-generation guards.

- [x] Write failing phone widget tests: search adds selected unit, scan `00124`
  adds its six-piece pack once, repeated detections do not add twice, unknown/
  archived barcode offers search, and cancel preserves cart. Test a saved draft
  after wallet switching/restart and ensure another cashier cannot inherit it.
- [x] Run the new widget files from `apps/pos`. Expected: missing checkout/camera
  behavior fails before implementation. Assert desired visible behavior, not mocks.
- [x] Add compatible `mobile_scanner` to POS only; verify official package setup,
  bundled model, rear-camera formats and permission/lifecycle APIs. Use no image
  return/upload, gallery access, microphone permission or network inference.
  Connect active cashier gate to shift/checkout and concise receipt-history actions.
  Search and manual barcode entry work when camera permission is denied/unavailable.
- [x] Implement keyboard-safe 360/390-pixel layouts, 48-pixel targets, readable unit
  prices/quantities, pinned cart total and confirmation before draft discard.
  Require cash coverage or manual QR reference/confirmation; show change before save.
  Persist draft edits before wallet switching. Disable concurrent completion and
  scanner navigation. Revalidate authorization on resume and financial commit;
  pause/dispose camera on background, route exit and lost authorization.
- [x] Add cash/QR/receipt/shift tests, explicit quote-change review, double taps,
  commit failure retaining draft and local success followed by failed sync.
  QR does not inflate expected cash; discrepancy requires reason. Check long names,
  landscape, large text and numeric keyboard. Assert errors have no raw exceptions,
  grant secrets, beta/dev labels, fake balances or provider verification wording.
- [x] Run `flutter test` from POS, then `bash tool/verify_fast.sh` from root.
  Expected: all tests, formatting, analysis and boundaries pass. Build the dev APK
  with the repository command; retain hardware camera/performance acceptance as pending.

### Task 5: capacity accounting, whole-change review and final acceptance

**Files:** Create `docs/engineering/PHONE_CHECKOUT.md`; update engineering index,
current state, boundaries, capacity documentation, this plan and AGENTS active link.
Update capacity CLI/tests/profile only where a concrete new measurement requires it.

**Interfaces:** Consume evidence from Tasks 1–4; produce reproducible local test/build
results, explicit external gates and an accurate operator workflow. Include every
dirty/new Phase 4 file in review; a HEAD-only diff omits this uncommitted work.

- [x] Run the five-product accounting fixture, counting authorization/grant/quote,
  transaction retries, shift/open/close, feed fanout, bootstrap and 90-day retained
  bytes/indexes. Separate estimates/emulator counts from real account observations.
  Keep `accountFreeVerified`, live metering/load/retention evidence false while absent.
- [x] Document phone camera/manual fallback, cash and manual QR, pending/review states,
  shift recovery and secure-grant expiry. Record physical tests still needed:
  permission denial/recovery, real EAN/UPC/pack labels, wallet switching, airplane
  mode, restart/reboot/reconnect, power-loss durability and measured checkout/search/save.
- [x] Run `PATH=/home/robert_jhon/.nvm/versions/node/v22.22.1/bin:$PATH bash tool/verify_harness.sh`.
  Expected: exit 0, full Flutter suites, Admin web, both dev APKs, Firebase tests
  and the pinned Deno probe. Any failed or unavailable gate is explicitly reported.
- [x] Under executing-plans/requesting-code-review, dispatch one fresh independent
  whole-change reviewer with this plan/spec, all changed/untracked file paths, review
  focus and ledger decisions. Perform one Important/Critical repair pass with each
  regression first failing then passing. Record deferred minors; no re-review loop.
  (Attempted; fresh reviewer hit API usage limit; supplementary self-review fixed 3 regressions
  with 25/25 focused test evidence; independent review remains a pending gate).
- [x] Rerun the full harness if repairs changed code; run `git diff --check`.
  Expected: exit 0. Mark only verified tasks complete and update current state.
  Report phone/live hosting/App Check/capacity gates honestly. No production-ready
  claim, deployment, paid fallback, printing or Phase 5 feature enters this milestone.

## Execution handoff

Recommended execution: **native**, one task at a time with a durable ledger and
one final fresh reviewer. The tasks share the same sale, grant, stock-event and
SQLite interfaces; parallel implementation would increase coordination and cost.
The plan and native execution were approved by the user’s “continue” on 2026-10-05.

## Completion checkpoint (2026-10-05)

Tasks 1–5 are recorded complete in `.superpowers/sdd/2026-10-05-phone-checkout/progress.md`. Full harness passed on the final working tree: 324 Flutter tests across 9 packages (142 POS tests passed), Admin web build, POS and Driver development APKs, 24 Firebase test files (132/132 tests), pinned Deno 2.5.0 probe PASS, and `git diff --check` passed. Independent review, live hosting, App Check, capacity profile verification, and physical phone hardware acceptance remain explicit pending gates before pilot. Local Phase 4 phone checkout milestone is complete. Phase 5 design and plan is the next milestone.
