# Phone checkout operations

Phase 4 implements local checkout under the [approved phone design](../superpowers/specs/2026-10-04-phone-checkout.md). Firebase remains on Spark. Nothing in this milestone enables billing, deploys services or authorizes a pilot. Configure the existing HTTPS backend as described in [FREE_BACKEND.md](FREE_BACKEND.md).

## Cashier workflow

1. Sign in on an activated Android phone. Open a shift with the counted opening float, or resume that cashier's open shift. Another cashier cannot take over the shift or saved cart.
2. Search saved products by name/SKU/barcode. Choose the selling unit and its price. **Scan** opens the rear camera; one detection adds one matched unit, then closes the camera. A pack barcode adds one pack with its recorded base-unit conversion. Scan again explicitly for another item.
3. If the camera is unavailable, use manual barcode entry or search. Permission recovery offers **Retry camera** and **Camera settings**. No photos are saved or uploaded. No tablet, external scanner, gallery or microphone is required.
4. Change quantities in the cart. Catalog refresh never silently changes quoted prices. **Review prices** shows changes and unavailable units before **Apply changes**. **Discard cart** requires confirmation.
5. **Pay** opens cash or QR entry. Cash must cover the total; change is shown before save. For QR, check the bank/wallet yourself, enter its reference, and confirm the check. This is a manual record; the application does not verify or process payment. QR contributes zero to expected drawer cash.
6. **Save payment** first saves a fixed payment UUID and tender, then commits the sale locally. Duplicate taps cannot create a second receipt. A failed commit retains **Finish saved payment** with the original UUID/tender. Do not collect payment again when retrying that saved payment.
7. Read the receipt and select **New sale**. **Receipts** searches local history, including payment references, in pages of fifty. Receipt prices remain historical. **Saved locally · Sync pending** means payment is durable on this phone; **Needs review** means server reconciliation requires attention. A network failure does not undo a locally saved sale.
8. **Shift** records cash in/out with a reason. Expected cash is opening float plus cash sales plus cash in minus cash out. Close with counted cash; a discrepancy needs a reason. Complete or discard a cart before closing. Pending shift operations and receipts remain listed locally.
9. **Sync** pulls bounded feeds and uploads up to twenty ordered checkout operations. Repeat while work remains. **Lock** returns to cashier selection without erasing business files.

Draft edits survive leaving payment, switching to a wallet, and process restart. If the process stops after a sale commits but before its receipt is presented, reopening checkout displays that same receipt. Reboot invalidates offline authorization and requires online sign-in; it does not delete the receipt or cart. An interrupted opening/close remains recoverable through the local shift and outbox.

## Authority and persistence

Permanent online PIN verification issues a grant bound to merchant, branch, device, cashier and credential version. Its random secret is kept only in encrypted device storage and passed separately over HTTPS. SQLite, receipt payloads and cloud operation records contain only the grant reference. The server stores a secret hash.

Financial writes recheck the active cashier, cached device/credential/grant bindings, seven-day expiry and same-boot monotonic evidence. Missing evidence, expiry, lock, reboot or observed revocation blocks new payments. A definitive denial also removes active offline credentials, so resuming or restarting cannot restore revoked authority. Previous grant secrets remain available for pending uploads. Server reconciliation still checks current device/cashier status, assignment and credential version; retaining a secret does not bypass revocation. Original intent time must fall within its grant window. Device time is bounded evidence, not independent proof against a compromised device.

The merchant/branch SQLite file preserves versions 1, both observed version 2 schemas and version 3. Version 4 adds immutable checkout events, receipts, tenders, stock deltas, cash movements, outbox and drafts. Version 5 adds a mutable receipt-presentation recovery pointer. Migration tests reopen existing v3/v4 files and preserve history, cursors and pending work. One transaction commits sale, tender, aggregated stock, cash movement, shift, outbox, recovery pointer and draft removal. Failure injection rolls back the whole transaction.

Stock feeds carry one atomic event for up to twenty sale products; legacy count changes remain compatible. A matching feed can settle a sale even if its upload acknowledgement was lost. Feed gaps or changed acknowledgements fail closed without advancing the cursor. Counts wait for prior local sales to settle; a pending absolute count's display subtracts every later local sale until the count resolves. Checkout never uploads human-only count drafts.

Blocked/conflicting operations retain immutable intent and local effects. Dependencies stop at the first unresolved operation. This milestone has no automatic correction, deletion, reordering, void/refund, payment reversal or cloud-history cleanup. Those require later approved workflows. Sign-out, lock and revocation preserve business data; uninstalling or clearing Android application data can destroy unsynced local records.

## Capacity worksheet

The emulator fixture is `firebase/functions/test/checkout/checkout.emulator.test.ts`. It counts transaction document reads and attempted writes; query reads count returned documents, with a minimum of one. It is local structural evidence, not live billing, index, network or hosting evidence.

| Operation | Reads | Writes | Fixture assumptions |
| --- | ---: | ---: | --- |
| Open shift | 9 | 3 | One successful transaction attempt |
| Five-product sale | 20 | 9 | Five quotes, five stock positions, one atomic feed event |
| Exact sale replay | 7 | 0 | Current authority is checked again |
| Cash in / cash out | 9 | 2 | Valid amount/reason and ordinal |
| Close shift | 9 | 3 | Matching counted cash |
| Resolve five legacy quotes | 8 | 0 | Five distinct indexed product/revision pairs |

Grant authorization is included in these counts: three device-authority documents plus cashier, credential and grant. Do not add those six reads again to the sale total. Grant issuance/PIN checks, roster refresh, rejected requests, token revocation lookup, App Check, management and other platform features are additional workloads. Contention can retry transaction reads; the concurrent-device regression proves stock convergence, not a fixed retry rate. Count actual attempts under representative live contention before filling the profile.

At five stores × 200 receipts/day with five distinct products each, first-attempt sale transactions alone imply **20,000 reads and 9,000 writes/day**. Ten phones opening and closing one shift each add 180 reads and 60 writes/day. Every replay adds seven reads; every cash movement adds nine reads and two writes. Legacy quote resolution is needed only when local catalog provenance is missing, not for every normal scan.

Every subscribed device eventually reads the branch's sale feed. With two phones/store, 1,000 sale events/day imply 2,000 additional event-document reads before authorization, feed metadata, empty queries and retries. Catalog and stock pulls read at most fifty events/page and five pages/feed/action. Avoid constant polling; current sync is explicit and receipt-triggered. A simultaneous cold catalog bootstrap of 3,000 products on ten phones adds at least 30,000 product-event reads before stock/authentication. Stage initial bootstrap; sale and cold-download workloads together exceed the 40,000-read engineering budget.

Ninety days at this receipt rate retain at least **90,000 immutable sale envelopes and 90,000 sale-feed events**, plus grants, shift/cash operations, catalog history, current projections and indexes. The five-product fixture measured 1,413 envelope JSON bytes and 348 event JSON bytes (1,761 combined), excluding Firestore document-name/type overhead and indexes. That JSON-only example totals about 151 MiB over ninety days before those additional costs. Multiply the measured per-receipt retained size including indexes by 90,000, then add the fixed dataset and all other platform facts. Do not use JSON size as a storage certification. Archival, verification, deletions and restore belong to Phase 8; no records are pruned now.

Published Firestore free limits are 50,000 reads, 20,000 writes/deletes per day and 1 GiB storage. This project uses lower engineering budgets of 40,000 reads, 16,000 writes/deletes and 750 MiB including indexes. TTL, managed backup and restore require billing and are excluded. See [Firestore quotas](https://firebase.google.com/docs/firestore/quotas) and [storage/query accounting](https://firebase.google.com/docs/firestore/pricing), checked 2026-10-05. Firestore also has its own 10 GiB/month outbound-transfer quota. Measure that separately from the hosting egress allowance; the current capacity profile does not certify Firestore transfer.

`FREE_CAPACITY_PROFILE.json` intentionally retains null observations and false evidence flags. `npm run check:capacity` must return **exit 2 (unproven)** until actual free-account, traffic, Firestore metering and retention evidence exists. Deno request/CPU/egress/loaded-instance memory budgets remain those in `FREE_BACKEND.md`; local probe RSS/elapsed time cannot substitute for billed loaded-instance hours. No paid fallback is authorized.

## Verification and remaining acceptance

Run `bash tool/verify_fast.sh` during edits and `PATH=/home/robert_jhon/.nvm/versions/node/v22.22.1/bin:$PATH bash tool/verify_harness.sh` before completion. The latter checks all Flutter packages, Admin web, both Android dev APKs, backend build/unit/emulator/rules tests and the pinned Deno 2.5.0 probe. Automated scanner tests inject detections and permission/lifecycle behavior; they do not prove optical scanning on hardware.

Physical phone acceptance remains pending: real EAN/UPC/Code128/pack labels, rear-camera focus in shop lighting, denial then settings/re-enable, wallet switching, airplane mode, process restart, reboot/online recovery, reconnect/revocation, power-loss durability, and cross-device stock convergence. Record device/Android version and measured trained cash checkout under 60 seconds, search under 200 ms and durable save under one second. Verify normal/200% text, keyboard/landscape and permission recovery on that device.

Live free hosting eligibility, deployed IAM/HTTPS security, actual App Check/release signing, realistic quota/retention measurements and independent review remain release gates. All full-platform milestones must pass before a real-world pilot. Optional printing, automatic payment verification, refunds/voids and Phase 5 refunds/promotions/credit remain outside this phase.

Supplementary author self-review reproduced and repaired three recovery regressions: authorization in flight cannot override an observed denial; revocation dismisses checkout child routes before sign-in; failure to mark a receipt presented preserves its durable payment and recovery pointer. The fresh independent reviewer was dispatched but hit its usage limit before reviewing; independent acceptance remains pending. Deferred minor: stale camera-unavailable text after successful retry, while preview and detections work.

Phase 4 verification status: full engineering harness (`tool/verify_harness.sh`) passed cleanly on 2026-10-05. All 324 Flutter tests across 9 packages (including all 142 POS tests), Admin web build, POS and Driver development APKs, and 24 Firebase test files (132 tests) passed on emulators alongside the pinned Deno 2.5.0 probe. `git diff --check` passed cleanly. All Task 1–5 local milestones are complete. Independent review, live hosting, App Check, capacity verification, and physical phone acceptance remain explicit external gates before pilot. Next milestone: Phase 5.
