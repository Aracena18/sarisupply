# Phase 3: catalog, local stock and synchronization

## Authority and scope

Implements Phase 3 of the approved free platform specification. The user has
explicitly authorized continued local implementation despite pending live hosting
and capacity acceptance. Firebase remains Spark; trusted commands use the existing
Deno-compatible HTTPS dispatcher. No deployments or paid services.

## Catalog

Owner manages a merchant catalog: stable product ID, unique SKU, name, base unit,
active/archive state, integer PHP centavo prices, and up to 12 named sale units.
Each unit converts to a positive integral number of base units and may have a
unique barcode. Base unit conversion is 1. SKU/base unit are immutable after
creation; sale-unit changes do not rewrite historical stock. Barcodes are strings
so leading zeros survive. Editing requires expected revision and stable operation
ID; retries cannot overwrite a concurrent edit. Archive retains history and
barcode ownership. Cashiers and scoped managers can read catalog; only owners can
change merchant-wide prices/products.

## Stock and local persistence

Stock quantities are integral base units, including negative balances. Opening
stock is recorded once per branch/product. Owners and scoped managers reconcile
shortages by recording a physical count with a reason and expected stock revision.
Every accepted movement is immutable; corrections append movements. This phase
provides no checkout, purchasing, batch/expiry or sale mutation API.

A focused SQLite adapter uses versioned, transactional migrations. Separate files
are bound to merchant/branch, verified again in stored metadata. Product data,
server stock, immutable local movements, outbox, and sync cursors survive restart.
Recording an opening/count commits its movement and outbox in one transaction
using an operation UUID generated before commit. Local counts are visible even
when upload is uncertain; they never disappear on sign-out/revocation. Pending,
accepted/duplicate, conflict and blocked outcomes remain inspectable. A rejected
count can be explicitly withdrawn by appending a local compensating entry; an
uncertain or accepted operation cannot be withdrawn until a definite response.
No credentials or PINs enter SQLite.

## Sync

Separate merchant catalog and branch stock sequence feeds, 50 changes per page,
with independent durable cursors. Payload/projection/cursor apply atomically;
invalid/gapped/malformed responses cannot advance cursors. Each stock snapshot
carries the operation ID so a lost ACK cannot double-count a committed local
movement. ACK before delta also must not double-count. A sync action consumes at
most 5 pages per feed and 20 outbox operations; remaining work stays durable and
is explicitly shown. No realtime polling/listeners or full-rescan-per-reconnect.

Device reads derive merchant/branch from current device state; spoofed scope is
rejected. Human reads/writes recheck current membership and branch in transactions.
Only online human authority can upload stock setup/counts; offline recording is a
local draft, not cached owner authority. Cashier sessions read saved inventory but
cannot upload owner stock drafts. Permanent authorization denials pause uploads
without deleting business data. Network, quota and malformed ACK failures retain
pending work. Feed/operation data and registry documents are server-only under
existing deny-by-default rules.

## UX and acceptance

Manage store exposes Catalog and stock with an accessible branch selector,
search, product/unit/barcode forms, opening stock and physical counts. Cashier
workspace shows locally searchable product/unit prices, stock and shortages.
No technical/beta copy. Saved locally, pending/review and retry states are concise.
Local search is bounded to 50 visible rows; exact barcode lookup returns its unit.
Tests cover reopen/migration, atomic rollback, scope mismatch, barcode uniqueness,
concurrency/idempotency, partial/lost ACKs, cursor rollback, negative stock and
rejected-count compensation. Emulator/rules tests exercise tenant, branch and
revocation denial. Final harness and independent review are required. Hardware
latency, live quota/hosting and device App Check remain external release gates.
