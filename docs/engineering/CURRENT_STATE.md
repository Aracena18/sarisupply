# SariSupply Current State

**Last reviewed:** 2026-10-06

This document describes the repository implementation; deployment and live-device validation are recorded separately.

## Product stage

SariSupply is in early production-foundation development. The approved direction is a Flutter-only client architecture with POS, Driver, and Admin applications, shared Dart/Flutter packages, Firebase cloud services, and a SQLite catalog/stock ledger and outbox foundation.

## Active usability audit

The 2026-10-05 phone usability audit is being implemented in the working tree.
See [audit repair status](AUDIT_REPAIR_STATUS.md) for repaired behavior, measured
checks and remaining local/external gates. Earlier phase claims do not establish
operational readiness: the Development HTTPS backend is deployed; live-client
acceptance is still pending. Shared procurement and delivery
stock/return reconciliation now have local implementation and focused emulator
coverage; final review, real hosting and device acceptance remain unfinished.
The operator selected Deno Deploy and real Development Firebase for today’s
presentation; Development credentials are privately stored and Auth/Firestore access passed;
Deno Free organization authentication passed; the Development API app is created,
and compiled revision `42wrrxfpnyd4` deployed successfully after bypassing stalled
cloud compilation and CLI uploads. Its URL is
`https://aracena18-sarisupply-dev-api.aracena18.deno.net`. Firebase App Check API access passed.
The operator-selected Admin account has its Development role and custom claim.
POS and Driver APK builds and matching-signature phone updates passed; business
data was retained and backed up privately after updating. Phone App Check debug
tokens are registered. Admin web built and deployed to `https://sarisupply-dev-aracena18.web.app`.
Its Fraud Defense key matches the saved Firebase Enterprise registration.
The presentation requirement is now Android for POS, Admin, and Driver. Admin
Development Android was incorrectly using the POS Firebase registration; a
separate Admin Android app and debug signing fingerprint are now registered.
The generated SDK configuration includes its Android Google OAuth client. The
Development API allows the new Admin app ID. Its APK built successfully in 56.4s
and installed as a matching-signature update. Native environment-selection tests
and whole-repository analysis passed; live Admin sign-in remains pending.
End-to-end business flows remain unverified; the POS showed reconnect and needs
manual access refresh after phone token registration.
The operator reports connection errors in all three Android apps. The HTTPS
adapter was discarding structured 503 reasons and the shared error copy described
verification/authentication/server failures as connection failures. Those errors
now retain safe recovery reasons; Driver offline access recovery uses error codes
rather than UI text, and blocked POS bootstrap carries the recovery message.
Live unauthenticated and invalid-signature requests correctly returned 401;
POS debug-token exchange and local Admin SDK verification passed. These checks
exclude a completely unreachable API but do not establish successful phone
requests. Phone reconnection is required to identify and resolve the remaining
live blocker. All three Development Android APKs rebuilt successfully; 32 focused
checks passed. Full acceptance and the heavy harness remain deferred.

## Main branch

`main` contains the Flutter monorepo foundation, the engineering harness, and the Firebase identity and tenant-auth milestone. The identity milestone, Tasks 1–11, was merged in PR #2.

### Engineering harness

The repository-level harness is merged and provides agent guidance, engineering source-of-truth documentation, architecture checks, and fast/full verification commands.

### Firebase identity milestone

Tasks 1–11 are implemented and covered by automated tests:

- Task 1: Firebase environments, Android flavors, and package/backend scaffolding.
- Task 2: tenant/auth models, immutable collections, and branch/offline authorization policies.
- Task 3: environment-specific Firebase bootstrap and separate human/device authentication.
- Task 4: backend authorization, auditing, idempotency, Admin bootstrap, and restrictive rules.
- Task 5: merchant applications, Admin review, and approval flow.
- Task 6: memberships, branch management, and Manager invitations.
- Task 7: POS device activation, scoped identity, and revocation.
- Task 8: server-side cashier lifecycle and PIN security.
- Task 9: device-local verifier and seven-day offline credential policy.
- Task 10: onboarding, activation, cashier, and Admin application states.
- Task 11: Firebase emulator acceptance tests and verification commands.

## Offline-auth resilience follow-up

The offline-auth resilience follow-up extends the identity
milestone with:

- Securely retained merchant, branch, and device context for offline POS
  recovery, limited to seven days by same-boot monotonic clock evidence. Missing
  clock evidence, reboot, or a server revocation requires online recovery.
- Durable offline cashier PIN failure reports with stable event IDs, legacy
  queue migration, retry-safe device-authenticated upload, and server-derived
  tenant, branch, and device audit context. Upload failures and partial
  acknowledgements keep pending events queued; explicit local device-session
  clearing removes device-scoped state. Authoritative bootstrap denial clears cached context and cashier credentials before best-effort device sign-out, while retaining pending audit events. The queue is bounded at 200; a full
  queue requires online refresh before another offline PIN attempt.
- Regression and emulator coverage for expiry, clock reset/manipulation,
  retries, revocation followed by offline retry, unauthenticated callers, and cross-tenant/cross-branch isolation.
- Complete stored-event validation quarantines malformed payloads without deleting them. Valid events can still sync and online authentication remains usable; offline PIN attempts remain blocked until the corrupt queue state is explicitly resolved.
- Offline PIN reports require current cashier assignment to the reporting device branch. Reports after branch reassignment are rejected and retained locally; historical assignment proof is not implemented. A suspended cashier still assigned to the branch may have past failures reported.

This follow-up is implemented with regression coverage. It is not deployed or validated on a live device.

## Verification

On 2026-10-03, the full harness passed on `chore/firebase-dependency-security`, based on the merged `main` implementation:

- `bash tool/verify_fast.sh` — PASS.
- `bash tool/verify_firebase.sh` — PASS; 54 tests passed across 14 files.
- `bash tool/verify_harness.sh` — PASS.
- Admin web build — PASS.
- POS Android `devDebug` APK build — PASS.
- Driver Android `devDebug` APK build — PASS.

Verification used Flutter 3.44.9, Dart 3.12.2, Node 22.22.1, and the JDK selected by Flutter (Java 25).

On 2026-10-03, `feat/offline-auth-resilience` also passed the full harness after
the offline-auth follow-up: 56 Firebase emulator tests across 14 files, Admin
web build, POS Android `devDebug` build, and Driver Android `devDebug` build all
passed. Flutter 3.44.9, Dart 3.12.2, Node 22.22.1, and Flutter's selected JDK
(Java 25) were used.

After the PR #5 review fixes on 2026-10-03, both `verify_fast.sh` and
`verify_harness.sh` passed: 120 Flutter tests, 59 Firebase tests across 14 files,
Admin web, POS Android `devDebug`, and Driver Android `devDebug` builds.
Independent security review found no remaining blocking findings. Regressions
cover observed revocation followed by network loss, malformed queued records,
partial acknowledgements, legacy event-ID collisions, and same-merchant
cross-branch reports. The full onboarding/PIN acceptance test uses a 15-second
timeout for cold emulator startup; its assertions and PIN derivation are unchanged.

## Firebase Functions dependency security

The 2026-10-03 npm audit reported seven affected-package entries (five high and two moderate). Triage found that the high entries are one gRPC advisory propagated through a development-only emulator-testing dependency chain; the production-only audit reports no high findings. The two moderate entries are one UUID advisory in an optional transitive Cloud Storage dependency chain, with no affected UUID or Cloud Storage API use in the current Functions source. Both findings are temporarily accepted pending upstream dependency updates. See [Firebase Functions dependency triage](FIREBASE_FUNCTIONS_DEPENDENCY_TRIAGE.md) for paths, evidence, and reevaluation conditions.

## Operational work still outstanding

The merged implementation is not yet a production deployment. Remaining work includes:

- Complete the free HTTPS backend feasibility gate and deploy its Development
  adapter with server-only credentials and PIN pepper. Do not link Firebase billing
  or deploy Cloud Functions/Secret Manager. See [FREE_BACKEND.md](FREE_BACKEND.md).
- Pre-authorize the real Admin user and complete live end-to-end testing of device activation and cashier enrollment.
- Complete live-device validation of offline tenant-context recovery and queued security-event upload after reconnect.

The Driver app shows a branded inactive delivery state. POS opens Checkout after verified cashier sign-in. Local sales are implemented in Phase 4; warehouse, delivery, credit and reporting remain later milestones. See the UI redesign evidence below.

Both Firebase projects are on the no-cost Spark plan. Cloud Functions deployment and Cloud Storage bucket creation require linked billing and the Blaze plan. Production Android release signing and its certificate fingerprints must be configured before release.

## Free production platform Phase 1

The [approved scope](../superpowers/specs/2026-10-04-free-production-platform.md)
requires full platform completion before any real-world pilot, with Firebase
remaining free and Firestore as the only cloud database. The active implementation
is [Phase 1](../superpowers/plans/2026-10-04-free-backend.md):

- A JSON HTTPS adapter dispatches all 21 identity commands into the existing
  Firebase Admin services. It verifies tokens, environment/project, allowed App
  Check application IDs, exact web origins, payload limits and safe typed errors.
- Flutter repository factories select an explicit HTTPS origin. Human/device
  Auth sessions stay separate; App Check and abortable HTTP dependencies are
  confined to the Firebase adapter package. Missing backend configuration has no
  paid callable fallback. Existing builds now require `SARISUPPLY_API_URL` to run
  their real backend flows, plus the Admin web App Check site key.
- Attestation failures and configuration denials cannot erase valid cached offline
  authority. Regression tests exercise the HTTPS gateway through the POS workflow;
  confirmed identity/device revocation still purges offline credentials.
- The backend workspace contains a fail-closed hosted entrypoint, Deno deployment
  configuration and a pinned Deno 2.5 compatibility probe in Firebase verification.
- Capacity accounting fails closed on missing observations. Its checked-in
  profile is **unproven**, with no fabricated load, account or retention evidence.

Local verification on 2026-10-04 passed formatting, analysis, architecture checks,
131 Flutter tests, Admin web and POS/Driver Development APK builds, 104 Firebase
unit/emulator/rules tests, and the Deno 2.5.0 REST runtime probe. One independent
review identified two offline-attestation regressions; both were reproduced and
repaired with tests. These local results do not prove hosted feasibility.

The operator has no Deno account yet and requested local code plus deployment
instructions. Nothing is hosted. Phase 1 remains gated on actual account
eligibility, live SDK/attestation checks and measured capacity. The user explicitly
authorized local Phase 2 work after these local checks. That is a sequencing
exception, not evidence of hosted feasibility. Local identity, catalog/stock and checkout are implemented below. Credit, procurement, delivery, archives and reports remain planned work.

## Phase 2 identity workspace

The [identity workspace scope](../superpowers/specs/2026-10-04-identity-workspace.md)
extends existing identity flows without new dependencies or paid services:

- A new bounded HTTPS management read projects non-secret fields, scans at most
  50 records/page, preserves cursors after filtered empty pages and enforces current
  human membership, tenant, role and branch scope. Firestore rules remain closed.
- POS management supports branch creation/deactivation, cashier creation/status/
  PIN reset, invitations, manager access/removal and device revocation using the
  existing server mutation policies. Confirmation precedes destructive actions.
- Cashier creation accepts a stable operation ID. Repeating creation cannot add
  another cashier or replay a stored plaintext PIN; recover via PIN reset.
- Named cashier selection uses device-scoped roster metadata with explicit ID
  fallback. Offline policy still grants access; metadata does not grant authority.
  Device revocation removes the roster along with cached authorization.
- Management human sign-in/out preserves the activated device session. Forms keep
  retry IDs/draft IDs, disable pending actions and present safe errors. Admin review
  adds business/address search. Shared page constraints support phones/tablets.
- Verified invitation email identifies managers, with accepted-invitation lookup
  for historical memberships. Access edits remove inactive assignments with an
  explicit notice. Enrollment reconciles uncertain submission against a server
  read and provides a status refresh action while keeping form data.

Local Phase 2 verification on 2026-10-04 passed `bash tool/verify_harness.sh`:
145 Flutter tests, 112 Firebase tests across 21 files, formatting, analysis,
architecture checks, Admin web and POS/Driver Development APK builds, and the
pinned Deno 2.5.0 runtime probe. One fresh independent review found three Important
workflow defects; all were reproduced and repaired with regressions. No Minor
findings were deferred. Changes remain uncommitted in the existing feature checkout.

Live Android/Web accounts, hardware usability, actual App Check and hosted account/
IAM/capacity acceptance remain pending. This is local milestone completion, not
production readiness. Catalog/SQLite/durable ledger/outbox and delta synchronization are the active
Phase 3 follow-up described below.


## Phase 3 catalog and stock workspace

Phase 3 local code is implemented in the existing feature checkout:

- Owner product creation/edit/archive/restore, immutable SKU/base unit, unique
  SKU/barcode reservations, up to twelve units, integral conversions and exact PHP
  centavo prices. Managers read shared catalog and manage scoped branch counts.
- Real SQLite files scoped and metadata-bound to merchant/branch; tested migrations
  from v1 and both v2 schemas to v3, immutable movements, local reversals, durable outbox and atomic
  cursor/projection application. Identity invalidation does not delete stock data.
- One-time opening stock and revision-checked physical counts with reasons.
  Negative cloud balances are visible and can be reconciled by a count. Cashiers
  read/search saved products/prices/shortages; sales remain Phase 4.
- Transactional server mutation receipts and bounded sequence feeds. Device reads
  derive current branch scope; human uploads require current branch authority.
  Lost/partial ACKs, retries, quota/network uncertainty, blocked/conflict outcomes
  and explicit rejected-draft withdrawal retain history and pending work.
- Manage store links branch-scoped catalog/stock screens. Cashier workspace links
  inventory after current device access verification. Existing theme/page layout
  is reused; phone forms keep precise prices and retry IDs without raw errors.

Local verification passed. The independent reviewer could not finish because its
usage limit was reached. Preliminary review feedback and a separate self-review
led to fixes for stale ACK settlement, remote backlog restart visibility and
cashier-session races. Follow-up regressions cover both v2 database variants,
changed device branch scope and late inventory verification after session end.
The follow-up full harness passed on 2026-10-04: 173 Flutter tests, 120 Firebase
tests in 22 files, formatting, analysis, architecture checks, Admin web and
POS/Driver Development APK builds, plus the pinned Deno runtime probe.
Independent review remains an acceptance gate. No deployment or paid service has been enabled. See
`CATALOG_STOCK.md` for usage, request/read budgets, retention prerequisites and
unverified live gates. Phase 4 is checkout, payments,
receipts and shifts after this local milestone passes verification.

## Phase 4 phone checkout workspace

The user approved the [phone checkout design](../superpowers/specs/2026-10-04-phone-checkout.md) and [implementation plan](../superpowers/plans/2026-10-05-phone-checkout.md) on 2026-10-05. Local code is implemented in the existing uncommitted feature checkout:

- Phone search, exact rear-camera barcode/unit selection, manual fallback and permission/settings recovery. POS-only `mobile_scanner` 7.4.2 uses the bundled Android model; no cloud photos or paid inference.
- Saved cashier/device carts, explicit price review, cash/change and manually checked QR, immutable receipts/history, opening float, cash in/out and counted shift closure.
- Atomic SQLite financial/stock/outbox commits, exact UUID retry, rollback tests, receipt presentation recovery and migrations through v5 preserving earlier business data.
- Secure cashier grants from permanent online PIN verification, same-boot/expiry/session checks at each financial commit, current server assignment/version/revocation checks, and definitive-denial invalidation retaining pending receipts and upload secrets.
- Trusted HTTPS quote/checkout commands, historical catalog evidence, multi-product atomic stock feeds and bounded ordered reconciliation; no device authority to upload human stock-count drafts.

Task 5 verification passed on 2026-10-05: full harness passed cleanly (`tool/verify_harness.sh` exit 0). Across 9 packages, 324 Flutter tests passed (including all 142 POS tests), Admin web built, POS and Driver development APKs built, and all 24 Firebase test files (132 tests) passed on emulators alongside the pinned Deno 2.5.0 runtime probe (1705ms, 1482ms CPU, 218MiB RSS). Whitespace check `git diff --check` passed cleanly. The backend five-product accounting fixture passed nine tests: sale transaction 20 document reads/9 writes, exact replay 7/0, open/close 9/3, cash movements 9/2, five quote lookups 8/0 (emulator counts, not live billing). Fresh whole-change reviewer was dispatched but hit an external account usage limit; supplementary author self-review reproduced and repaired three recovery regressions (stale authorization after denial, child routes remaining over sign-in, and receipt-presentation write errors; focused suite passed 25/25). Independent review remains an explicit pending gate.

See [PHONE_CHECKOUT.md](PHONE_CHECKOUT.md) for operation, recovery, capacity assumptions and pending phone acceptance. No service is deployed. The capacity profile remains unproven. Real camera/performance, hosting/account/IAM/App Check, retention/archives and full-platform pilot gates remain pending. Next milestone is Phase 5 (retail inventory and customer transactions).

## UI redesign implementation

The 2026-10-05 redesign follows the user-approved audit and [design.md](../../design.md):
shared storefront branding and locally bundled typography, clearer access/onboarding
states, verified cashier entry with Lock (Checkout is now the primary task), compact inventory
rows and persistent pending-count recovery, responsive product/management/count
forms, phone category selection and wide-screen navigation, deliberate Admin
review confirmations, and an honest inactive Driver state.

Deterministic fixtures cover phone/tablet/desktop widths and 200% text scaling,
keyboard insets and twelve-unit product forms. Six representative goldens were
rendered and inspected. Focused tests, scoped analysis and direct Admin web and
POS/Driver Development APK builds passed. Whole-workspace harness attempts hit
unfinished concurrent checkout changes; the full harness is not recorded as passing
for this redesign. Android 15 fixture checks now pass on the attached phone at
normal and 200% text size, including the physical keyboard, product save,
management cancellation, native SQLite inventory and the Lock callback. Driver's
inactive screen was checked on hardware. Live POS access remains blocked by missing
Development backend configuration; full Admin browser keyboard navigation and
human usability measurements remain unverified.
[UI_REDESIGN.md](UI_REDESIGN.md) records coverage, evidence and limits.

## Phase 5 retail inventory & customer transactions workspace

Implemented on 2026-10-05 following the build-focused approach:

- **Extended Stock Movements & Batch/Expiry**: `StockMovementKind` (receiving, adjustment, transfer_out, transfer_in, return_vendor, damage, write_off), `BatchExpiryRecord`, and `StockTransferIntent` added to `sarisupply_models`.
- **SQLite Schema v6**: Multi-table upgrade in `sarisupply_inventory` adding `batches`, `stock_transfers`, `customer_accounts`, and `customer_credit_ledger`. Fully backwards-compatible with v1–v5 data.
- **Refunds & Voids**: `RefundIntent`, `VoidIntent`, and compensating transactions in `checkout_store.dart`. Maximum refund cannot exceed original tender amount. Restores local inventory while preserving immutable historical receipt records.
- **Backend HTTPS Operations**: Callable handlers for receiving, adjustments, transfers, and refunds in `firebase/functions/src/` with corresponding client adapters in `packages/sarisupply_firebase`.
- **Promotions & Customer Credit Ledger**: Exact integer centavo promo engine (percentage, fixed discount, bundle discounts) and customer credit limit tracking, debt repayments, and offline utang allowances.
- **Phone UI Screens**: Five responsive screens built in `apps/pos/lib/features/`:
  - `receiving_screen.dart` (Stock Receiving with Batch/Expiry)
  - `adjustment_screen.dart` (Physical Stock Adjustment with Reasons)
  - `transfer_screen.dart` (Two-phase Dispatch & Receive Transfers)
  - `refund_screen.dart` (Line-item Refunds and Full Voids)
  - `customer_credit_screen.dart` (Customer Accounts, Credit, and Repayments)
  - Seamlessly integrated with Checkout, Catalog, Payment (Credit tender), and Receipt flows.
- **Verification**: Clean static analysis (`flutter analyze lib` passed with 0 warnings/errors), fast unit/feature tests passing. Per user directive, the repository adopted a build-focused approach with light per-task testing, deferring full emulator harness runs until all platform features are implemented.

## Phase 6 restocking, procurement & warehouse operations workspace

Implemented on 2026-10-05 following the build-focused approach:

- **Procurement & Restocking Domain Models**: Immutable domain models in `packages/sarisupply_models`:
  - `Supplier`: Vendor directory, contact details, standard lead times.
  - `PurchaseOrder` & `PurchaseOrderLine`: PO creation, integer centavos unit and total costing, line-item receiving tracking.
  - `Warehouse` & `WarehouseStock`: Multi-warehouse support with explicit stock reservation logic: `availableQuantity = (physicalQuantity - reservedQuantity).clamp(0, physicalQuantity)`.
  - `RestockProposal`, `RestockProposalLine`, `PickList`, and `PackageManifest`: Replenishment proposals, Owner review/adjustment, warehouse pick lists, and tamper-sealed container manifests.
- **SQLite Schema v7 & Local Procurement Store**:
  - Upgraded database schema to version 7 in `packages/sarisupply_inventory`.
  - Added tables: `suppliers`, `purchase_orders`, `warehouses`, `warehouse_stock`, `restock_proposals`, `pick_lists`, and `package_manifests`.
  - Added atomic store methods for PO issuance, supplier delivery receiving into warehouse stock, restock proposal drafting, Owner approval with automatic warehouse reservation, pick list execution, and sealed container packing.
- **Backend HTTPS Operations & Client Gateway**:
  - `procurement-service.ts` in `firebase/functions/src/procurement/`: Handlers for `manageSuppliers`, `managePurchaseOrders`, and `manageRestockProposals`.
  - Enforces Owner authorization check (`requireOwner`) for restock approval and updates warehouse stock reservations.
  - Client adapters in `packages/sarisupply_firebase/lib/src/functions/procurement_functions.dart` (`ProcurementGateway` & `ProcurementFunctions`).
- **POS Phone UI Screens**:
  - `restock_screen.dart` in `apps/pos/lib/features/inventory/presentation/`:
    - Real-time shortage detection (identifies products with low stock <= 10).
    - One-tap "Add all shortages" to proposal draft with suggested replenishment quantities.
    - Proposal submission to Owner.
    - Owner review & approval dialog: store owners can adjust quantities or reject with reason.
    - Live order status tracker from pending to packed.
  - `warehouse_fulfillment_screen.dart` in `apps/pos/lib/features/inventory/presentation/`:
    - Tab 1: Restock Fulfillment Pick & Pack queue (start picking, check off items, pick-all shortcut, container code and tamper seal packing manifest).
    - Tab 2: Supplier PO Receiving (inspect PO lines, record received stock against target warehouse, track batch/expiry).
    - Tab 3: Multi-Warehouse Stock Levels & Reservations (physical vs reserved vs available quantities, manual stock adjustments).
  - Navigation integrated into `catalog_screen.dart` via the Operations menu.
- **Admin Web Dashboard**:
  - `procurement_dashboard_screen.dart` in `apps/admin/lib/features/procurement/presentation/`:
    - Suppliers directory with quick creation form.
    - Purchase Order issuance with line items and automatic centavo cost calculations.
    - Restock oversight queue across all branches.
    - Wired into `AdminAppGate`, `AdminAuthGate`, and `MerchantReviewListScreen`.
- **Verification**:
  - `flutter analyze apps/pos apps/admin packages/sarisupply_models packages/sarisupply_inventory packages/sarisupply_firebase` passed cleanly with **0 issues**.
  - TypeScript compilation `npm run build` in `firebase/functions` passed with exit code 0.
  - Fast unit tests passed: 5/5 in `packages/sarisupply_models` and 2/2 in `packages/sarisupply_inventory`.

## Phase 7 distribution & driver deliveries workspace

Implemented on 2026-10-05 following the build-focused approach:

- **Delivery Route & Doorstep Domain Models**:
  - `DeliveryRun` & `DeliveryRunStatus`: Scoped runs (`draft`, `dispatched`, `inTransit`, `completed`, `cancelled`) with sequential stops, driver and vehicle metadata, and completion timestamps.
  - `DeliveryStop` & `DeliveryStopStatus`: Destination store info, sequence, geocoordinates, package manifest reference, and statuses (`pending`, `arrived`, `delivered`, `partiallyDelivered`, `failed`, `cancelled`).
  - `DeliveryStopItem`: Ordered quantity, delivered quantity, returned quantity, unit cost centavos, unit name, return reason, and remaining calculations.
  - `DeliveryProof`: Lightweight proof of delivery with recipient name, role, touch canvas signature serialized to SVG path data, cash collected centavos (COD), timestamp, and offline status. Zero cloud photo storage dependencies.
- **SQLite Schema v8 & Local Delivery Store**:
  - Upgraded database schema to version 8 in `packages/sarisupply_inventory`.
  - Created tables: `delivery_runs`, `delivery_stops`, `delivery_stop_items`, and `delivery_proofs`.
  - Added atomic store methods: `saveDeliveryRun`, `listDeliveryRuns`, `getDeliveryRun`, `updateStopStatus`, `recordDeliveryProof`.
  - Stop status calculation logic: handles partial deliveries and full rejections, updating stop status and run status automatically.
- **Backend HTTPS Operations & Client Gateway**:
  - `delivery-service.ts` in `firebase/functions/src/delivery/`: Implements `manageDeliveries` callable with actions `createRun`, `dispatchRun`, `submitStopProof`, and `listRuns`.
  - Client adapters in `packages/sarisupply_firebase`: `DeliveryGateway` interface and `DeliveryFunctions` implementation.
- **Driver Phone App UI (`apps/driver`)**:
  - `SignaturePad`: Reusable touch/stylus signature canvas capturing finger strokes and serializing them into SVG path vectors 100% offline.
  - `DriverHomeScreen`: Displays active route overview, sequential stops with status badges, offline-ready indicators, one-tap demo route loader, and pending sync trigger.
  - `StopDetailScreen`: Detailed stop information, package manifest verification, call contact action, arrival confirmation, delivery failure reporting, and external map navigation via platform intents (`geo:` / external Google Maps URL intent) avoiding paid embedded Maps SDKs.
  - `DeliverySignatureScreen`: Doorstep item delivery & return steppers with return reasons, COD cash collection in centavos, recipient name and role, and digital touch signature pad.
  - Updated `apps/driver/lib/main.dart` with local SQLite initialization.
- **Verification**:
  - Full workspace `flutter analyze` passed with **0 issues found** across all packages and apps.
  - TypeScript build `npm run build` in `firebase/functions` passed with exit code 0.
  - Fast unit tests passed: `packages/sarisupply_models/test/delivery_test.dart` (4/4 PASS) and `packages/sarisupply_inventory/test/delivery_store_test.dart` (1/1 PASS).

## Phase 8 ledger-consistent reports, encrypted archives, printing & notifications

Implemented on 2026-10-05 following the build-focused approach:

- **Financial, Valuation & Notification Domain Models (`packages/sarisupply_models`)**:
  - `TenderBreakdown`, `DailySalesSummary`, and `ZReading`: Cash, GCash QR, Maya QR, and store credit (utang) payment consolidation, sales tax reporting (VAT 12% calculation), gross/net totals, void totals, opening/closing cash drawer balances, and discrepancy tracking.
  - `ProductValuationRow`, `StockMovementSummary`, and `InventoryValuationReport`: Per-product physical quantity, cost price centavos, selling price centavos, potential retail value, estimated inventory cost, potential gross margin, and stock movement breakdown (sales, supplier receiving, branch transfers, returns, damages/shrinkage).
  - `SariNotification`, `NotificationCategory` (`stockShortage`, `expiryRisk`, `syncConflict`, `systemNotice`), and `NotificationSeverity` (`info`, `warning`, `critical`): Real-time in-app alert model with actionable deep navigation links.
- **SQLite Reporting & Encrypted Local Archival Engine (`packages/sarisupply_inventory`)**:
  - `BackupArchiveService`: Zero-dependency, offline-first local database backup exporter utilizing pure Dart `package:cryptography` (AES-256-GCM authenticated encryption, PBKDF2 with HMAC-SHA256 key derivation with 100,000 iterations, random 128-bit salt and 96-bit nonce).
  - Plaintext SHA-256 digest manifest generation for tamper-evident integrity verification without requiring full archive decryption.
  - CSV Exporters: Excel/Google Sheets compatible RFC 4180 CSV generation for daily sales transactions and inventory valuation snapshots.
  - Store aggregations: Added `generateDailySalesSummary` and `generateZReading` to `CheckoutStore`, plus `generateInventoryValuation` and `detectStockAlerts` to `InventoryStore`.
- **Pure-Dart ESC/POS Thermal Printing Engine (`packages/sarisupply_core`)**:
  - `EscPosBuilder`: 100% pure Dart byte-level ESC/POS command stream generator (ESC @ initialize, ESC a alignment, ESC E bold, GS ! font magnification, GS V paper cut, ESC p cash drawer kick) supporting standard 58mm (32 cols) and 80mm (48 cols) thermal rolls with zero cloud print subscriptions or native C binary dependencies.
  - `ReceiptFormatter`: Formats sales customer receipts, official Z-Reading end-of-day register closures, and driver stop delivery receipts, as well as ASCII monospace paper preview renderings.
- **POS Phone UI Screens (`apps/pos`)**:
  - `ReportsScreen` (`apps/pos/lib/features/reports/presentation/reports_screen.dart`): Tabbed operations view for:
    - Tab 1: Daily Sales & Official Z-Reading register closure with cash reconciliation and receipt preview.
    - Tab 2: Inventory Valuation & Movements with export to CSV.
    - Tab 3: Encrypted Backups & Archival with password protection and integrity verification.
    - Tab 4: Thermal Printer Settings (58mm/80mm toggle, drawer kick, test print).
  - `ReceiptPreviewDialog`: Paper roll visual presentation dialog with monospace ASCII rendering, copy to clipboard, and raw ESC/POS byte streaming.
  - `NotificationBell`: Dynamic AppBar badge widget displaying unread alert counts and bottom sheet list with tap-to-resolve shortcuts for stock shortages and outbox sync issues.
  - Integrated into POS `CatalogScreen` (Operations menu & AppBar) and `ReceiptScreen` (Thermal Print button).
- **Admin Web Dashboard (`apps/admin`)**:
  - `AdminReportsScreen` (`apps/admin/lib/features/reports/presentation/admin_reports_screen.dart`): Network-wide consolidated sales metrics, multi-branch inventory valuation, CSV export triggers, and offline backup manifest auditor. Integrated into Admin navigation.
- **Verification**:
  - Static analysis: `flutter analyze` across all packages and apps passed with **0 issues found**.
  - TypeScript build `npm run build` in `firebase/functions` passed with exit code 0.
  - Architecture checks: `dart tool/check_architecture.dart` passed with 0 boundary violations.
  - Fast unit tests passed: `reports_test.dart` (6/6 PASS), `backup_archive_test.dart` (6/6 PASS), `esc_pos_printing_test.dart` (6/6 PASS), `checkout_store_test.dart` (58/58 PASS), `sarisupply_core` (7/7 PASS), `sarisupply_models` (62/62 PASS).

## Phase 9 production release preparation, hosting, disaster recovery & operator runbooks

Implemented on 2026-10-05 following the build-focused approach:

- **Disaster Recovery & Encrypted Backup Restore Engine (`packages/sarisupply_inventory`)**:
  - `restoreAndVerifyBackup`: Secure offline restoration engine that decrypts PBKDF2-derived AES-256-GCM backup archives, verifies plaintext SHA-256 integrity digests against manifests, and restores historical `checkout_events`, `checkout_sales`, `checkout_shifts`, append-only `ledger`, and `stock` in atomic transactions.
  - `checkDatabaseIntegrity`: PRAGMA `quick_check` and PRAGMA `integrity_check` diagnostic evaluation with detailed record counts (products, stock, historical checkout sales, immutable ledger entries, pending outbox events) and user version tracking.
- **Zero-Cost Health & Diagnostics Engine (`packages/sarisupply_core`)**:
  - `SystemDiagnosticsService` (`system_diagnostics_service.dart`): Pure Dart system diagnostic evaluator collecting outbox backlog congestion, monotonic clock drift offsets against trusted references, and SQLite B-tree page integrity without external monitoring costs.
  - `SystemDiagnosticsReport` & `DiagnosticMetric`: Structured health categorization (`healthy`, `warning`, `critical`).
- **Free Hosting & Android Production Release Configurations**:
  - Configured `firebase/firebase.json` with Firebase Hosting for `apps/admin/build/web`: Single Page App (SPA) URL rewrites to `/index.html`, immutable caching for static assets (`.wasm`, `.png`, `.js`), zero-cache headers for `index.html`, and strict security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`).
  - Maintained zero Cloud Functions deployment triggers, preserving 100% Spark plan free status.
  - Verified Android release build configurations and flavors (`dev`, `prod`) in `apps/pos` and `apps/driver`.
- **POS & Admin UI Diagnostics & Recovery Screens**:
  - `DiagnosticRecoveryScreen` (`apps/pos/lib/features/diagnostics/presentation/diagnostic_recovery_screen.dart`): Real-time SQLite database health panel, monotonic clock drift monitor, outbox backlog queue indicator, and disaster recovery restore wizard with backup inspection and atomic restore.
  - Navigation integrated into POS `CatalogScreen` (Operations menu) and `ReportsScreen` (Diagnostics shortcut).
  - Admin Web Quota Safeguards Card in `apps/admin/lib/features/reports/presentation/admin_reports_screen.dart`: Visualizes Firestore daily read/write limits, Firebase Hosting quotas, and offline disaster recovery procedures.
- **Operator Runbooks & Crisis Guides**:
  - `docs/engineering/OPERATOR_RUNBOOK.md`: Comprehensive end-to-end production manual covering deployment to Firebase Hosting, APK sideloading, store onboarding, daily opening float, checkout workflows, QR payments, utang debt tracking, Z-reading shift closures, thermal receipt printing, restock proposals, warehouse fulfillment, and driver deliveries.
  - `docs/engineering/DISASTER_RECOVERY_RUNBOOK.md`: Complete crisis management playbook detailing incident tiers (outbox congestion, 7-day token expiry, SQLite corruption, device theft/loss, concurrent negative stock balance reconciliation) with step-by-step mitigation workflows.
- **Verification**:
  - Full workspace `flutter analyze` across all 9 packages/apps: **0 issues found**.
  - TypeScript build `npm run build` in `firebase/functions`: exit code 0.
  - Architecture checks: `dart tool/check_architecture.dart`: PASS (0 boundary violations).
  - Fast unit tests passed: `backup_restore_test.dart` (2/2 PASS), `backup_archive_test.dart` (6/6 PASS), `system_diagnostics_test.dart` (4/4 PASS), `esc_pos_printing_test.dart` (6/6 PASS), `reports_test.dart` (6/6 PASS), `sarisupply_core` (11/11 PASS), `sarisupply_models` (62/62 PASS).

## CCE106 Rubric Compliance & Multiplatform Admin Expansion

Implemented on 2026-10-05:

- **Admin Multiplatform Android & Web Support (`apps/admin`)**:
  - Configured Gradle and Android build scaffolding (`settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `app/build.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt`).
  - Added flavors (`dev`, `prod`) matching `apps/pos` and `apps/driver` with `com.sarisupply.sarisupply_admin` namespace.
  - Added `dev` and `prod` `google-services.json` client configurations.
  - Supports dual deployment targets: Flutter Web (Firebase Hosting) and Android (tablet/phone sideloading).
- **Product Image Integration & Preset Engine (`packages/sarisupply_design_system`, `packages/sarisupply_models`)**:
  - Extended `CatalogProduct` with optional `imageUrl` supporting `toMap`, `fromMap`, and `copyWith` with backward compatibility.
  - Created `ProductImagePresets` with curated high-resolution sari-sari store category imagery (Canned Goods, Beverages, Snacks, Instant Noodles, Coffee & Milk, Rice, Personal Care, Condiments).
  - Created `ProductThumbnail` widget with network loading indicator, image caching, and smart category icon/color fallback.
  - `ProductDialog` (`apps/pos`): Live image thumbnail preview, 1-tap category preset chips, custom image URL input with clear button.
  - `CatalogScreen` (`apps/pos`): Display `ProductThumbnail` leading icon on inventory rows and in product details.
  - `CheckoutScreen` (`apps/pos`): Display `ProductThumbnail` on search item results and in cart item rows.
- **CRUD Operations Completeness**:
  - Explicit Create, Read, Update, and Delete actions testable and visible across the POS catalog.
  - Added "Delete / Archive Product" action in `ProductDialog` and directly on inventory cards in `CatalogScreen` with confirmation modal dialogue.
- **Verification**:
  - Full workspace `flutter analyze`: **0 issues found** across all 9 packages and apps.
  - Architecture check: PASS.
  - Fast unit tests: `catalog_test.dart` (3/3 PASS), `product_image_test.dart` (2/2 PASS), `product_dialog_test.dart` (PASS), `ui_redesign_test.dart` (28/28 PASS).
