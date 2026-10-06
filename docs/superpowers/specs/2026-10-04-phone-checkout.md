# Phase 4: phone checkout and cashier shifts

Status: design approved by the user on 2026-10-05 (“Proceed next”). Phase 4
implementation plan was approved by “continue” on 2026-10-05. Local code is implemented; full verification and independent review are in progress. External release gates remain pending.

## Intent and authority

The user authorized continuing to Phase 4 on 2026-10-04 and specified that barcode
scanning must use a phone camera. Current testing hardware is a phone; a tablet
is not required. This design applies the approved free platform scope to checkout,
payments, receipts and shifts. It does not certify a production release.

Firebase stays on Spark with no billing account. Use the existing trusted HTTPS
backend and Firestore; do not deploy Cloud Functions, add paid services, a payment
processor, cloud photos or another cloud database. The user has authorized local
Phase 4 work despite pending hosting/capacity acceptance. Deployment and pilots
remain gated by the full platform specification.

## Selected approach

Extend the existing scoped SQLite inventory database so checkout and stock share
one transaction. Keep money/cart/shift policies in shared Dart code, persistence
in infrastructure, camera handling in POS, and server authorization in the trusted
backend. Continue using existing design-system components.

A separate checkout database would make sale/stock atomicity harder and require
cross-database recovery. Online-only checkout would break the approved offline
workflow. Neither alternative is selected.

## Phone workflow

1. Cashier signs in and opens or resumes their device's shift.
2. Checkout shows product search, a prominent Scan button and a compact cart.
3. Scan opens the rear camera full-screen. One successful detection returns to
   checkout and adds exactly one unit. Scanning another item is an explicit action;
   repeated camera frames cannot increase quantity. Search supports name/SKU and
   exact manual barcode entry.
4. Cashier edits unit/quantity or removes a line. A pinned cart total opens payment.
5. Cash or QR payment completes one durable local transaction, then opens a receipt.
6. New sale clears only the completed cart. Receipt history remains searchable.

Use a single-column portrait layout, SafeArea, keyboard-aware scrolling and at
least 48 logical-pixel action targets. Check 360-pixel and 390-pixel phone widths,
landscape, large text, long product names and an open numeric keyboard. Primary
actions stay reachable; no tablet split layout, decorative graphics, fake metrics,
beta/development labels or verbose instructional panels are required.

Persist the cart and unfinished payment inputs as a nonfinancial draft scoped to
device, branch and cashier. Leaving checkout, process restart or switching to a
bank/wallet app must not lose it. Revalidate cashier authorization on resume and
before local financial writes. Another cashier cannot inherit the draft silently.
Discarding a draft is explicit and cannot delete a completed sale.

## Camera behavior and dependency

Use `mobile_scanner` in `apps/pos` only, with the bundled Android ML Kit model.
The package's bundled model is available immediately; the unbundled option
downloads its model on first use. Bundling is selected for offline first-use
scanning, accepting the package's documented APK-size increase.
[Package documentation](https://pub.dev/packages/mobile_scanner)

Request camera permission only when Scan is tapped. Provide concise retry and
permission-recovery actions plus manual entry/search when denied or unavailable.
Start/stop/dispose the camera with route and application lifecycle; pause it while
backgrounded or when a payment app is open. Never retain or upload camera frames.
[Android permission workflow](https://developer.android.com/training/permissions/requesting)

Recognize common retail EAN/UPC, Code 128, Code 39 and ITF barcodes. Match exact
strings against the local unit registry, preserving leading zeros. An unknown or
archived product cannot be silently added or created by a cashier. Show the
barcode and offer search. A pack barcode selects its configured pack unit; an
item barcode selects its configured base unit. Do not interpret product QR codes
as payment confirmations. No external scanner hardware is needed in this phase.

## Cart, payments and receipt

Prices and calculations use integer PHP centavos. Quantities are positive integers
of the selected sale unit; stock movements use its integral base-unit factor.
The cart records product/unit/price snapshots and the catalog event/revision used
for the quote. A refresh cannot silently reprice a cart: show an explicit price
update for review before payment. Completed receipts never change with catalog edits.

Bound each receipt to 50 lines and 20 distinct products. Reject integer overflow,
invalid factors, nonpositive quantities and totals above 1,000,000,000 centavos
before collecting a tender. Insufficient local/cloud stock does not block a physical
sale; resulting shortages remain visible for reconciliation. Discounts, returns,
voids, customer credit and split tenders belong to Phase 5.

Cash requires received amount at least equal to total; compute and display change
before completion. QR requires the full total, a bank/wallet reference (1–80
characters) and explicit cashier confirmation that receipt of payment was checked
in the payment app. Store this as manual confirmation, never provider verification.
No QR fee integration, generated merchant account or automatic settlement.

The receipt contains a stable receipt identifier, store/branch, device/cashier,
shift, local sale time, product/unit/quantity/price lines, total, payment method,
cash received/change or manual QR reference. Keep local save and sync state distinct.
Show Saved locally after commit even if upload fails. History and receipt details
must reopen offline. These are internal sales records; printing/export is Phase 8.

## Atomic persistence and recovery

Generate the operation UUID before checkout. In one SQLite transaction write the
immutable sale, tender, per-product stock movements, shift cash movement, durable
upload intent and draft completion marker. A failure at any write rolls everything
back and leaves the draft recoverable. Retrying the same UUID and exact payload
returns its existing receipt; changed payload reuse is rejected. Double taps cannot
create another sale. On uncertain local completion, look up that UUID before retry.

Financial history is append-only with enforced database guards. Mutable projections
and upload status do not rewrite original finance records. Closing/signing out,
revocation and database upgrades preserve all pending work. Migration must support
version 1 and both observed version 2 schemas through version 3; future checkout
tables get a new schema version. No delete/recreate migration.

Count and sale projections must compose correctly. A pending physical count supplies
the absolute baseline, and later unsettled sale movements subtract from it. Once
server events arrive, acknowledged movements stop contributing locally at their
applied event sequence. Test count-before-sale, sale-before-count, concurrent POS
sales, negative balances, lost ACK, ACK-before-feed and partial retry explicitly.

## Cashier authorization and trusted synchronization

Device authentication alone cannot establish which cashier verified their PIN.
Extend successful online PIN verification and mandatory PIN change to issue a
random, unguessable cashier grant bound to current merchant/branch/device/cashier
and credential version. Persist only a hash of its secret server-side and the
secret in secure device storage, never SQLite, receipt bodies or logs. Grants
expire within the existing seven-day offline window. Existing installations need
one online PIN verification to obtain a grant before offline financial use.

Every local financial commit also checks the existing trusted same-boot offline
clock policy. Reboot or an expired window requires reconnect. A login session
already on screen does not bypass expiration. Ending a cashier session locks
checkout; resuming the same shift requires that cashier's authentication.

On upload, the server checks Firebase Auth/App Check, current merchant/branch/device,
cashier assignment/status, credential version and grant binding in the transaction.
The server may reconcile delayed operations created inside their original grant
window after grant expiry; an expired grant cannot authorize new local operations.
Reported offline event time is device evidence, not an independently verified
server timestamp. Record it separately from server receipt time. A compromised
authorized device remains outside the honest-client trust boundary.

Validate sale unit/price snapshots against immutable catalog events by exact event
ID, product ID and revision; avoid catalog scans. Retain events needed by queued
work and historical receipts. Recompute totals/change/base quantities server-side.
The client cannot choose its authority, server stock result or acceptance timestamp.
Reject scope/price/UUID tampering; retain the completed local record for review.

Upload intents in their durable device order, with open-shift before sales/cash
movements and close-shift after them. Bound each sync action to 20 intents and five
pages per feed. Accepted/duplicate results settle exactly once; conflicts/blocked
operations stay visible and stop dependent uploads. Timeouts, quota errors,
malformed responses and missing ACKs retain work for retry. Human-only stock drafts
cannot be uploaded through cashier authority.

Stock feeds must support a single atomic event containing all per-product changes
for one sale. Preserve legacy single-product count events when decoding. Apply the
whole event, its local operation acknowledgment and cursor in one transaction;
reject malformed/gapped events without partial application. One sale event avoids
one feed-document write for every receipt line and keeps pagination bounded.

## Shifts and cash accountability

One device has one active shift. Its cashier opens it with a nonnegative cash float,
records cash-in/cash-out with amount and reason, and closes it with counted cash.
Each phone tracks its own cash accountability; a shared drawer across phones is
not automatically reconciled in this phase. Only the shift's cashier can resume or
close it. For a forgotten PIN, use existing owner/manager PIN reset, then have that
cashier change the temporary PIN, sign in and close their shift before a replacement
cashier opens another. Forced closure or cross-cashier takeover is outside this phase.

Expected cash = opening float + net cash sales + cash-in − cash-out. QR sales never
increase expected cash. Closing records counted/expected/difference and a required
reason for a discrepancy. Closed shifts reject later sales/movements. A close saved
offline remains local until preceding intents settle; blocked preceding operations
must remain inspectable. No sale-history deletion or silent financial correction.

## Capacity and limits

Keep the approved 40,000 reads/day, 16,000 writes/day and 750 MiB budgets. A sale
with five distinct products should use one immutable operation/financial envelope,
five stock-document writes, one stock sequence write, one stock event and one shift
projection: nine writes before any separate authorization/order bookkeeping.
Count additional writes/reads explicitly; do not call this estimate a proven fit.
Avoid separate per-line cloud documents, realtime listeners and automatic polling.
Stage catalog bootstraps as already documented in Phase 3.

Before local milestone acceptance, update the capacity worksheet for grants,
transactions/retries, sales, shifts, delta fanout, retained catalog events and 90-day
record growth. Live free-account limits, load, camera performance and hardware
latency remain release gates. No automatic paid fallback.

## Delivery order and evidence

1. Repair existing schema/navigation regressions and verify the Phase 3 baseline.
2. Implement/test shared checkout policies, migration, atomic persistence and recovery.
3. Implement/test cashier grants, authorized server commands and bounded delta sync.
4. Implement/test phone search/cart/camera/payment/receipt/shift flows.
5. Run the repository harness, independent review and tested repair; update state docs.

Focused evidence must cover rollback at each financial write, restart during payment,
duplicate/reused UUID, missing/partial ACK, stale/catalog-changing quotes, lifecycle
and permission failure, repeated scanner frames, leading zeros/unit barcodes,
overflow, insufficient cash, manual QR without confirmation, shift discrepancies,
cross-tenant/branch/device/cashier uploads, revoked/version-changed/expired grants,
offline window expiry during an open cart and quota failure preserving work.

Automated widgets can verify scanner-result behavior and layout, not optical camera
performance. Test the dev APK on the user's phone with real product barcodes,
denied/reallowed permission, wallet switching, airplane mode, restart and reconnect.
Target trained cash checkout under 60 seconds, search under 200 ms and durable save
under one second; record device/OS and measurements before accepting those targets.

Implementation plan: `docs/superpowers/plans/2026-10-05-phone-checkout.md`.
No Phase 5–9 features, deployment or full production-readiness claim are included.
