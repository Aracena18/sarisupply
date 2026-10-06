# SariSupply coding-agent handoff — 2026-10-05

Copy the prompt below into the next coding agent. Paths are relative to the repository unless stated otherwise.

---

You are continuing SariSupply's approved production implementation. Work as a professional software engineer. Inspect the repository before proposing changes; preserve existing work and continue from the recorded checkpoint.

## Repository and authorization

- Repository: `/home/robert_jhon/My_Codes_2/sarisupply`.
- Current branch: `feat/offline-auth-resilience`.
- Current HEAD and Phase 4 task base: `783dc08af4a3fa513fb24eccaaa96e33a6d7432d`.
- The working tree contains substantial **uncommitted tracked and untracked work** from Phases 1–4 and a separate user-approved UI redesign. HEAD-to-HEAD comparison is empty; review `git diff` **and actual untracked source files**. Do not reset, clean, overwrite, stash away, commit, push, merge, deploy, or remove workspace artifacts without separate authorization.
- The user wants the **full planned platform** before a real-world pilot, built phase by phase. Practical operations and clean phone UX matter; avoid filler, fake metrics, beta/development wording and decorative assets without a purpose.
- **Firebase must remain free on Spark. No billing account, paid services, paid fallback, Cloud Functions deployment, Secret Manager, Cloud Storage or second cloud database.** The existing Functions directory also hosts server code and local emulator tests; its name does not authorize deploying Functions.
- The operator has **no Deno Deploy account yet**. Prepare local code and instructions; hosted feasibility is unproven. Local continuation through Phase 4 was explicitly authorized despite those live gates. That exception does not authorize deployment, a pilot or expansion into later milestones without the appropriate approved scope/design.
- Barcode scanning is **phone rear camera first**. No tablet or external scanner is required. Do not configure OmniRoute; the user dropped that request.

## What to do next

**Finish Phase 4 Task 5: final verification and acceptance bookkeeping. Do not start implementing Phase 5 yet.** Phase 4 code is implemented; the last full harness failed on an existing catalog widget test's asynchronous SQLite timing. That test has now been repaired and its focused suite passes, but the full harness has **not been rerun since that latest test repair**.

Read these sources first, without loading unrelated plans:

1. `AGENTS.md` — repository rules and verification requirements.
2. `design.md` — approved UI/copy contract, including Checkout as the cashier's primary task.
3. `docs/engineering/CURRENT_STATE.md` — actual implementation and pending gates.
4. `docs/superpowers/specs/2026-10-04-phone-checkout.md` — approved Phase 4 specification.
5. `docs/superpowers/plans/2026-10-05-phone-checkout.md` — approved implementation plan. User approved native execution with “continue” on 2026-10-05.
6. `.superpowers/sdd/2026-10-05-phone-checkout/progress.md` — durable execution ledger.
7. `.superpowers/sdd/2026-10-05-phone-checkout/task-5-brief.md` — exact unfinished task.
8. `docs/engineering/PHONE_CHECKOUT.md` — operator workflow, persistence, authority, capacity assumptions and external acceptance.

The ledger records **Tasks 1–4 complete**. Task 5 has **no completion line**. Do not rebuild Tasks 1–4 because a checkbox or older document suggests missing code. Some Phase 4 status wording still needs updating after the next verification run.

## Phase 4 implementation present

### Shared domain and SQLite

- Pure checkout/cart/tender/shift/grant contracts in `packages/sarisupply_models/lib/src/checkout/`, exported by the models package. PHP amounts use integer centavos. Maximum receipt: 50 lines, 20 distinct products, total 1,000,000,000 centavos. Unit conversions and base quantities are integral and bounded.
- `packages/sarisupply_inventory/lib/src/inventory_store.dart` owns the scoped merchant/branch SQLite file. `checkout_store.dart` is its facade/part; widgets do not receive raw database access.
- Schema version **5**. Existing v1, both observed v2 variants, and v3 business data are preserved. v4 adds checkout facts/outbox/drafts/catalog provenance. v5 adds a mutable receipt-presentation recovery pointer. Existing v4 financial data is preserved on upgrade.
- Sale UUID and exact tender are frozen before completion. One transaction writes immutable event, sale, tender, aggregated stock deltas, cash movement, shift projection, outbox, receipt-recovery pointer and draft removal. Rollback injection and restart tests cover this.
- Restart after commit but before receipt display opens the same existing receipt. A failed presentation-pointer write does not invalidate the committed payment; recovery remains pending.
- Legacy count feeds normalize into `StockEvent`; sale feeds carry one atomic event with up to twenty positions. ACK/feed order and replay must never double-subtract stock.
- Checkout sync uploads at most 20 ordered intents; inventory sync pulls at most five 50-event pages per feed/action. Blocked operations retain immutable local effects and stop dependent uploads. No automatic deletion, reordering or fake acceptance.

### Authority and backend

- A permanent successful online PIN check issues an `IssuedCashierGrant` with a random 32-byte secret and independent grant ID. Temporary/wrong/cooldown PIN checks do not issue it.
- Secrets live only in encrypted device storage, keyed by device/grant, and are transported separately from the immutable intent. Server records keep the secret hash; SQLite and receipt payloads keep a reference only. Renewal retains previous secrets for pending uploads.
- Every financial commit rechecks active cashier/session, scope, credential version, device context, grant expiry and trusted same-boot monotonic evidence. Reboot/missing clock/expiry/lock/observed denial blocks new payments and requires online recovery without deleting business data.
- Definitive denial is sticky, dismisses checkout child routes, and invalidates active offline credentials. A stale authorization result cannot re-enable checkout. An old session's denial cannot invalidate a renewed session.
- The server still checks **current** merchant/branch/device/cashier status, assignment, credential version, secret and original intent time. An expired grant can reconcile only an intent created within its original window under current valid authority. Device time is bounded evidence, not independent proof against a compromised device.
- Trusted HTTPS commands: `recordCheckoutOperation` and bounded indexed `resolveCatalogQuotes`. Source: `firebase/functions/src/checkout/`. Historical catalog quotes support previously completed offline receipts; uncompleted drafts require explicit price review if their current quote changes.
- Updated cashier/device services, HTTPS dispatcher, Firestore rules/indexes and pinned Deno runtime probe. Firestore client writes remain closed. Cashier sync does not upload Owner/Manager count drafts.
- Firebase adapters are in `packages/sarisupply_firebase/lib/src/functions/`, especially `checkout_functions.dart`, `inventory_functions.dart` and `cashier_functions.dart`.

### Phone UI

- `apps/pos/lib/features/checkout/`: controller, checkout/search/cart, scanner, payment, receipt/history and shift screens.
- `apps/pos/lib/app/{pos_app_gate,firebase_pos_workflow}.dart` composes Checkout after verified cashier sign-in. Lock returns to cashier selection and preserves local business files.
- POS-only `mobile_scanner` **7.4.2**, bundled Android model (`dev.steenbakker.mobile_scanner.useUnbundled=false`). Rear camera, one returned detection per scan, no image return/upload, no gallery/microphone. Supported formats include EAN/UPC, Code128/39 and ITF14; QR payments are entered manually.
- Camera denial offers retry, Android application settings, manual barcode and search. Pause/resume/dispose and duplicate-frame behavior have injected widget tests; real optical behavior still needs hardware acceptance.
- Android CAMERA permission and settings channel are in the POS manifest/`MainActivity.kt`. APK permission inspection found no microphone/gallery/media permissions.
- Saved cash/QR inputs, manual wallet confirmation/reference, change display, duplicate-save guard, original UUID retry, receipt/history and opening float/cash in/out/discrepancy close are implemented. QR adds zero to expected cash. Price refresh never silently changes a cart.
- Responsive tests cover widths 320/390/600/1024/1280, 200% text and keyboard behavior. These are automated fixtures, not a usability/performance certification.

## Verification: facts, not assumptions

All evidence paths below are inside `.superpowers/sdd/2026-10-05-phone-checkout/`.

- `task-1-tests.log`, `task-2-tests.log`, `task-3-tests.log`: earlier completed task verification, including real-file SQLite, grants, adapters, backend and Deno probe.
- `task-4-tests.log`: **PASS**, including 139 POS tests, POS dev APK build and `verify_fast.sh` with all Flutter packages. This predates three final recovery regressions and the latest catalog test repair.
- `self-review-red.log`: three added regressions failed first. `self-review-green.log`: their focused POS/controller/payment/gate suite **25/25 PASS** after one repair pass.
- `metering-expanded.log`: backend checkout fixture **9/9 PASS**. One-attempt counts: open/close 9 reads/3 writes; five-product sale 20/9; exact replay 7/0; cash in/out 9/2; five quote lookups 8/0. Serialized JSON: envelope 1,413 bytes, event 348 bytes. These exclude Firestore overhead/indexes and are not live billing observations.
- `capacity-check.log`: capacity CLI **exit 2, unproven**. `docs/engineering/FREE_CAPACITY_PROFILE.json` remains null observations/false evidence flags. Do not populate it with emulator counts to force a pass.
- `apk-permissions.log`: CAMERA present, no microphone/gallery/media permissions. An earlier dev APK exists at `apps/pos/build/app/outputs/flutter-apk/app-dev-debug.apk`; rebuild after latest changes before distributing it.
- `phase4-harness.log`: first full attempt failed on a cash-receipt widget assertion before real-time SQLite completion; bounded receipt waiting repaired that test.
- **`task-5-tests.log`: latest full attempt FAILED**, with POS **141 passed, 1 failed**. Failure: `device authorization denial requests gate recovery and retains business file` in `apps/pos/test/features/catalog_screen_test.dart`; `pumpAndSettle timed out` during initial async load. Harness stopped during fast tests, so it did not reach its final app builds/Firebase verification.
- Catalog tests now use a bounded real-time `pumpCatalogUntil` helper, initially pumping a frame to expose busy state, waiting for visible readiness before simulated `pumpAndSettle`, and awaiting store closure before temporary-file deletion. Assertions about authorization denial, retained business files, prices, shortages and barcode matching remain intact.
- **`catalog-test-final.log`: focused catalog suite 2/2 PASS after the latest repair.** `catalog-test-green.log` is an earlier failed intermediate attempt; its filename is not proof of success.
- `git diff --check` passed at handoff. No full harness pass is claimed for the final working tree. No tests/builds are still running at this checkpoint.

### Independent review limitation

The single fresh-context reviewer was dispatched to `gpt-6-astra`, but errored immediately due to the account usage limit. It did **not** review the change. No paid upgrade was requested. `.superpowers/sdd/2026-10-05-phone-checkout/review-package.md` lists tracked/untracked paths, plan/spec, review focus and ledger decisions. `self-review.md` records a supplementary author review. **Independent acceptance remains pending**, including the prior Phase 3 review that could not finish. Do not call author self-review independent approval.

The three self-review repairs already have RED→GREEN evidence:

1. Authorization started before denial cannot restore `allowed=true` afterward.
2. Revocation dismisses all child routes above the gate before showing sign-in.
3. Receipt-presentation metadata write failure cannot escape as an unhandled error after payment has committed.

One **deferred Minor** remains: camera-unavailable text persists after a successful retry even though the preview and scanning work. This was deliberately documented, not silently forgotten.

## Exact next actions

1. Read the ledger/Task 5 brief and inspect `git status`/actual files. Preserve this checkpoint. Apply repository implementation, offline review, Flutter quality, Firebase security, review and finish-task skills as relevant. Do not create multiple implementer/reviewer agents or duplicate full test jobs.
2. Run the full harness on the latest tree:

   ```bash
   cd /home/robert_jhon/My_Codes_2/sarisupply
   PATH=/home/robert_jhon/.nvm/versions/node/v22.22.1/bin:$PATH bash tool/verify_harness.sh
   ```

   Redirect its long output to this plan's workspace and inspect exit status and decisive results. The harness includes Flutter formatting/analysis/architecture/tests, Admin web, POS/Driver dev APKs, Node build/unit/emulator/rules tests and Deno 2.5.0. Do not declare completion from the earlier focused passes.

3. If another failure occurs, reproduce and fix its cause. For SQLite widget tests, simulated frame time cannot finish real FFI work. Wait for meaningful visible state within a bounded real-time deadline; do not weaken assertions, remove security tests, use arbitrary huge sleeps or skip failures. The current catalog helper change is test-only.
4. Complete independent review if an actually available reviewer can run. Inspect the full working change including untracked files. Keep the gate explicitly pending if unavailable. Any blocking finding needs a reproducing regression and repair; do not fabricate a successful review or launch repeated review loops.
5. Run final verification after code repairs and `git diff --check`. Update `CURRENT_STATE.md`, `PHONE_CHECKOUT.md`, the plan and ledger with actual counts/results and pending gates. Task 5 must not be marked complete before its local verification passes. Keep evidence artifacts because changes are intentionally uncommitted.
6. If using the existing execution helper, the task base remains the HEAD above:

   ```bash
   PATH=/home/robert_jhon/.nvm/versions/node/v22.22.1/bin:$PATH \
     /home/robert_jhon/.codex/plugins/cache/openai-curated-remote/superpowers/6.4.2/skills/executing-plans/scripts/task-done \
     docs/superpowers/plans/2026-10-05-phone-checkout.md 5 \
     783dc08af4a3fa513fb24eccaaa96e33a6d7432d \
     -- bash -c 'bash tool/verify_harness.sh && git diff --check'
   ```

   This records completion only if the command succeeds. Its completion line is local command evidence, not proof of hardware/hosting/review acceptance. Do not run a second duplicate harness just to record a line if an equivalent fresh result has already been properly recorded.

7. Report the local outcome and remaining gates clearly. Next planned Phase 5 covers receiving/counts/adjustments/transfers/batch-expiry/refunds-voids/promotions/customers/credit/repayments. Read the approved full-platform scope and prepare a bounded Phase 5 design/plan only after resolving this checkpoint and establishing the appropriate continuation/design authorization. Do not infer Phase 5 implementation approval from a handoff request.

## Full roadmap through release

The approved master scope is `docs/superpowers/specs/2026-10-04-free-production-platform.md`. It covers **nine phases**, not just checkout. Detailed implementation plans currently exist for Phases 1–4. Phases 5–9 have approved milestone scope, but **no detailed task-by-task implementation plans yet**. Do not treat the following roadmap as proof those features are implemented or as a substitute for inspecting code and writing each phase's design/contracts/tests.

### Existing phase plans and their remaining gates

| Phase | Scope | Implementation plan | Checkpoint |
| --- | --- | --- | --- |
| 1 | Free trusted HTTPS backend, identity transport, security and capacity feasibility | `docs/superpowers/plans/2026-10-04-free-backend.md` | Local implementation verified previously; actual free hosting/account/attestation/capacity acceptance remains pending |
| 2 | Identity, enrollment, branch/device management and recovery | `docs/superpowers/plans/2026-10-04-identity-workspace.md` | Local implementation verified previously; live end-to-end acceptance remains pending |
| 3 | Catalog, units/barcodes/prices, opening stock, SQLite ledger/outbox and delta sync | `docs/superpowers/plans/2026-10-04-catalog-stock.md` | Local implementation verified previously; unfinished independent review and live acceptance remain pending |
| 4 | Phone checkout, cash/manual QR, receipts and shifts | `docs/superpowers/plans/2026-10-05-phone-checkout.md` | Finish Task 5 at the checkpoint above; latest final working tree has no full-harness pass yet |

### Phase 5 — complete retail inventory and customer transactions

**Approved scope:** receiving, counts, adjustments, branch transfers, batches/expiry, refunds/voids, promotions, customers, credit and repayments.

**Goal:** stores can receive and reconcile goods, correct transactions without rewriting history, manage customer balances and apply predictable promotions.

Inspect existing count/cash/stock behavior before adding features; some scope already has foundations. Suggested planning sequence, **not an approved detailed plan**:

1. Store receiving/adjustments/transfers and batch/expiry tracking.
2. Authorized refunds/voids through compensating stock/tender/cash records.
3. Explicit promotion rules and historical discounted receipt evidence.
4. Customer balances, server-issued offline credit allowance and repayments.

**Required evidence before acceptance:** receiving/transfer retries cannot duplicate stock; transfer stages and partial completion are recoverable; batch/expiry quantities reconcile with the stock ledger; refunds/voids preserve the original receipt and cannot exceed the refundable quantity/value; promotion arithmetic remains exact; customer balances reconcile across devices and offline retries. Every sensitive command checks current scope and authority.

Credit has explicit master-spec constraints: allowance is reserved per customer/device on the server; expiry alone never makes unresolved allowance reusable; offline repayments do not replenish allowance before server acceptance. Do not improvise an unrestricted offline credit balance. Retain unresolved operations and open balances beyond the normal archive window.

### Phase 6 — restocking, procurement and warehouse operations

**Approved scope:** Owner-approved restocking, suppliers/procurement, multiple warehouses, receiving/reservation/pick/pack.

**Goal:** stock shortages lead to reviewable replenishment, procurement and warehouse fulfillment that an operator can complete in real work.

Distinguish Phase 5 store receiving from distribution/warehouse receiving here. Design the locations, order states, partial receipts and ledger transitions before implementation. Restock suggestions require Owner approval; no automatic purchasing or paid forecasting service is authorized.

**Required evidence before acceptance:** approval and supplier/order retries are idempotent; received, reserved, picked and packed quantities reconcile; concurrent allocation cannot silently promise the same stock twice; partial/cancelled orders preserve a clear audit and recovery path; roles and location scope are enforced; remaining stock and demand reflect accepted and pending work correctly. Include the added workload in the free-capacity worksheet.

### Phase 7 — dispatch and Driver workflows

**Approved scope:** scoped dispatch, Driver stops, navigation through the installed maps application, partial/failed deliveries, returns and collection, including manual coordination when offline.

**Goal:** assigned drivers can navigate, complete or explain each stop, record actual delivered/returned quantities and collections, and reconcile after reconnect.

Replace the currently inactive Driver workspace with real assigned work after an approved design. No embedded paid maps service or cloud proof photos are authorized. Delivery proof uses recipient, quantities, timestamp and structured metadata.

**Required evidence before acceptance:** drivers see only authorized assignments; duplicate stop submissions do not duplicate delivery/stock/payment effects; partial and failed deliveries leave recoverable remaining quantities; returns and collections reconcile with orders and financial ledgers; offline pending status is visible; manual coordination never falsely claims a server-confirmed assignment or completion. Test actual Android navigation and offline/reconnect behavior.

### Phase 8 — reports, archives, exports and optional printing

**Approved scope:** ledger-consistent reports/exports, encrypted archives, printing and notifications.

**Goal:** operators can trust totals, retrieve/export their records, preserve long-term history within the free storage budget and optionally print useful receipts.

Reports must derive from immutable business facts and identify pending/conflicting effects where relevant. Design bounded reads/aggregates and exports rather than scanning the full cloud ledger for every screen. No fake summary statistics or paid analytics service. Internal receipts carry no regulatory certification claim.

Retain 90 days of **settled** detailed online records and retain unresolved operations/open balances longer. Archival must produce encrypted files with manifests, prove restore and confirm **two owner-controlled copies before deleting cloud records**. No TTL, paid managed backup or unverified cleanup. Account for archive reads, indexes, deletions, restore cost and maintenance traffic.

**Required evidence before acceptance:** reports match independently calculated ledger totals; export/reimport handles exact money/units; interrupted/corrupt/incomplete archives are detected; restore reproduces the required history and balances; deletion cannot remove unsettled facts or occur before verified copies; relevant notifications reflect actual state. Printing is optional: implement/test applicable supported hardware when available, preserve the phone checkout path without requiring a printer purchase or tablet.

### Phase 9 — release and full-platform acceptance

**Approved scope:** release signing, free hosting, monitoring, restore/migration checks, operator instructions, regression evidence and rollback before pilot.

**Goal:** certify the full platform against its actual deployment, hardware, account and operations evidence. Local tests alone cannot satisfy this phase.

Required gates include:

- All prior phases implemented and verified, with blocking review findings resolved and unavailable gates explicitly closed through real evidence.
- Actual free-hosting eligibility/runtime/IAM/HTTPS checks, production Auth/App Check configuration and release-signing registration. Do not use debug attestation as production acceptance.
- Measured representative load including five-store sales, ten-device bootstrap/feed fanout, retries, reports and archival. Firestore stays within the engineering read/write/storage budgets; account for its own outbound transfer and hosting request/CPU/egress/loaded-instance-memory limits separately.
- Tested migrations from supported existing files, interrupted operations, quota exhaustion, backup/archive restore and safe release rollback without losing business data.
- Real phone camera, accessibility, cash/QR, shifts, inventory, credit, fulfillment and delivery acceptance; Admin browser interaction and relevant Driver/hardware checks.
- Operator setup, daily use, recovery and troubleshooting instructions based on the final behavior, plus suitable free monitoring and incident/rollback procedures.

The user requires the **full platform before a real-world pilot**. No automatic release is authorized by reaching a green harness. Live accounts, deployment and release actions require their applicable authorization; do not buy services or silently convert Firebase to Blaze to close a gate.

### How to advance without wasting work or tokens

Finish the current Phase 4 checkpoint first. For each subsequent phase, inspect only its affected code and authoritative scope, identify already-implemented foundations, write a bounded design and task plan, then follow `discover -> plan -> test/contract -> implement -> verify -> review -> repair -> final verify`. Save its progress ledger and update current state with concrete evidence.

Large phases may have smaller work packages, but those packages do not remove any approved capability. Preserve the current free-services and phone-first constraints throughout. Carry pending hosting/capacity/hardware/review gates forward explicitly; never relabel them as passed. If moving beyond the currently authorized local sequencing exception, establish the applicable continuation/design authorization instead of assuming it from this roadmap.

## Decisions already made — preserve or explicitly revisit

- Counts wait for preceding local sales to settle, and pending absolute-count projections subtract every later local sale. Reason: avoid ordering/double-count defects. Cost if wrong: counts remain blocked until sync.
- `IssuedCashierGrant` lives in pure models and the auth repository exposes it. Reason: transport/domain cannot import POS auth infrastructure. Cost if wrong: one model relocation.
- Separate mutable receipt-presentation pointer in schema v5, included in the atomic sale commit. Reason: recover after commit-before-display without collecting payment twice. Cost if wrong: extra local table/write/migration.
- Receipt merchant/branch names allow 300 characters, matching approved onboarding metadata. Cost if wrong: bounded extra receipt storage.
- The unavailable fresh reviewer was supplemented by author self-review while keeping independent acceptance pending. Cost if wrong: defects a fresh reviewer would find remain undiscovered.

## External gates and scope boundaries

Still pending: real phone barcode/focus/lighting, permission denial/settings/re-enable, wallet switching, airplane mode, restart/reboot/online recovery, reconnect/revocation, power-loss durability, multi-device live reconciliation and measured performance. Targets: trained cash checkout under 60 seconds, search under 200 ms, durable save under one second; record device/OS and measurements.

Also pending: free hosted account/runtime eligibility, deployed HTTPS/IAM security, real App Check/release signing, live Firestore/hosting metering, loaded-instance memory time, retention/archive/restore and full-platform acceptance before pilot. Firestore outbound-transfer quota must be measured separately from hosting egress; the current profile does not certify it. No cloud history is pruned now; archival belongs to Phase 8. No printing, automatic payment verification, void/refund or later-phase capability has been added to Phase 4.

Use existing Flutter clients and package boundaries. Apps may depend on shared packages; apps must not import each other; pure models must not import Firebase/Flutter app infrastructure. Preserve existing design/branding. No provider/credential/gateway configuration changes. No paid services or deployments.

Toolchain at checkpoint: Flutter 3.44.9, Dart 3.12.2, Node 22.22.1 at the explicit path above, pinned Deno 2.5.0. Root disk last had about 4.8 GiB free; monitor build space and never delete business files or unrelated work to free it.

Continue autonomously with these authorized local tasks. Ask only for genuinely missing required information or an action outside the authorized scope. Keep updates concise and make every completion claim match fresh evidence.

---

End of handoff prompt.
