# SariSupply implementation tasks

Approved approach: rebuild by verified slices, reuse correct code, replace mismatched behavior and preserve business data. Prepared 2026-10-06. This file authorizes a roadmap; it does not mean its features are already implemented. No feature task was executed when this guide was created.

**Current execution direction — 2026-10-06:** The presentation deadline
supersedes per-card ceremony: reuse working code, correct authorization/ownership,
then implement usable features across Admin, POS and Driver. Treat this guide as
the backlog. Follow AGENTS.md's presentation build mode; keep automated checks
light and leave hands-on testing to the user. AUTH-01 remains the auth reference.

## Authority and reading order

Read [AGENTS.md](AGENTS.md) and [SYSTEM_ARCHITECTURE.md](docs/architecture/SYSTEM_ARCHITECTURE.md) first. The canonical architecture owns business boundaries and permissions. This guide owns task sequencing and scope; it does not override that architecture. Inspect [CURRENT_STATE.md](docs/engineering/CURRENT_STATE.md) and affected source code to establish what actually works. Read [design.md](design.md) for every UI/UX/copy change, and the relevant approved milestone specification when needed.

Supporting scope: [production direction](docs/architecture/SARI_SUPPLY_PRODUCTION_PLAN.md), [approved free platform](docs/superpowers/specs/2026-10-04-free-production-platform.md), [engineering workflow](docs/engineering/AGENT_WORKFLOW.md), [boundaries](docs/engineering/ARCHITECTURE_BOUNDARIES.md) and [definition of done](docs/engineering/DEFINITION_OF_DONE.md). Older plans or code that put company warehouse operations inside a customer store must be reconciled with the canonical architecture.

One company owns its warehouses, Operations staff and riders. Independent stores own retail stock, sales, cashiers and POS devices. Company Owner is separate from Platform Admin. Company Owner enrolls riders; authorized company Operations dispatches them. Store Owners confirm commercial orders and actual received quantities. A rider's delivery proof does not itself post store inventory, settle payment or record remittance. Cashiers do not need Google accounts; their branch/device/PIN authorization remains separate. Existing delegated Store Manager support is retained inside store scope.

## How to use one task

1. Start with **AUTH-01**. After its contract is integrated, choose any task whose dependencies are integrated; the group headings are navigation, not compulsory waterfall phases.
2. Select the specified model and reasoning in Codex before pasting the task's entire `Copyable task` block. The launch command selects them explicitly; text inside a prompt does not change an already-running agent's model.
3. Inspect and reuse the allowed files. Each ordinary implementation task delivers one narrow usable feature through server/storage/UI where relevant. Contract tasks freeze shared decisions first; `-90` tasks independently review and integrate the resulting milestone.
4. Record evidence in the task's unique handoff file. A coordinator reviews the diff, integrates it and updates only that task's checklist row. Start a dependent worker only after its prerequisites are integrated.
5. Keep external/manual acceptance visible. A build pass with an unavailable printer, backend, device or identity is local completion with a pending acceptance gate, not verified production readiness.

Read only the selected card, its published contract and necessary prerequisite handoffs. Do not load this entire guide into every small agent. A model has a scope budget, not permission to silently simplify architecture or skip required behavior. If a complete slice cannot fit its scope, stop at the evidence-backed finding and let the coordinator split it or amend the allow-list before continuing.

Authorization needs a real warehouse before staff invitations: after AUTH-02, integrate SETUP-00, SETUP-01 and SETUP-02, then continue AUTH-05/AUTH-06. SETUP-90 waits for AUTH-90; early setup tasks do not. This ordering deliberately avoids an invitation/setup cycle.

## Model selection and cost control

| Profile | Exact model | Reasoning | Assigned work |
| --- | --- | --- | --- |
| LM | `gpt-6-luna` | `medium` | Established UI/copy, bounded documentation and simple reuse. |
| LH | `gpt-6-luna` | `high` | Narrow features with established contracts and existing components. |
| SM | `gpt-6.1-sol` | `medium` | Moderate server/storage work or focused integration. |
| SH | `gpt-6.1-sol` | `high` | Authorization, finance, idempotency, migration and independent review. |
| AH | `gpt-6-astra` | `high` | Exceptional bounded escalation after a documented blocker; no default tasks. |

Model IDs and CLI configuration were checked against [OpenAI model documentation](https://learn.chatgpt.com/docs/models) and [Codex CLI reference](https://developers.openai.com/codex/cli/reference/). These are routing choices for this repository, not measured token savings. Availability depends on the account/provider. If a model is unavailable, report it; the coordinator chooses an available model with comparable capability before work resumes. Do not change global providers, gateway settings, credentials or aliases to make a task launch.

Escalation protocol: preserve the original task ID, contract, allow-list and failing evidence. First retry with clearer context or split the slice. If it still requires broader reasoning, the coordinator may explicitly select `gpt-6-astra`, `high`, for the unresolved question only, then return the bounded implementation to the original worker. An agent must not silently switch models or start extra agents. Launch example: `codex -m gpt-6-astra -c 'model_reasoning_effort="high"'`.

## UI and UX acceptance for every feature

Follow the current Warm Utility design and shared `sarisupply_design_system`; reuse its actual components, tokens, fonts and icons. Keep Company Operations in Admin, retail work in POS and assigned delivery work in Driver. Authorization changes may add only the needed role-specific entry/navigation; no unrelated redesign.

Every touched workflow needs loading, empty, denied, validation, failure, retry, pending/offline and success states as applicable. Preserve input on retry; prevent duplicate submissions; make destructive or financial actions explicit. Show the selected business/branch/warehouse, useful status and next action. Label local/pending/source/freshness rather than inventing totals. Money uses the established centavo policy; dates and unit labels follow existing contracts. Never show internal UIDs as an enrollment step.

Manual UI evidence covers 320/390 px phone widths, 200% text, reachable touch targets of at least 48 px, keyboard/focus, scroll, back navigation and role switching. Check 600/1024 px layouts when the changed screen supports tablet/wide use. Show honest GPS permission, camera and printer failure states. Screenshots supplement observed workflow evidence; do not replace it. Do not add heavy per-screen widget matrices during building.

## Scope, data and verification rules

The allow-list is a boundary. Paths marked `planned` are proposed creation locations, not proof that equivalent code is missing. Contract authors must verify existing APIs and explicitly publish additive schemas, ownership checks, stable operation IDs, duplicate/conflicting replay behavior, UI states and shared-file wiring before downstream workers implement them. Reuse an existing correct handler instead of introducing a parallel service solely to match a proposed filename. The coordinator records any path replacement in this guide before two workers start.

Do not delete or reset SQLite/Firestore business data, clear durable queues, rewrite historical finance, auto-adopt ambiguous legacy ownership or change authentication cryptography. Preserve stable operation IDs, immutable attempted payloads and accepted results. Authoritative server checks validate ownership and current access; offline work follows the published durable-outbox and same-boot authorization policies. Observe revocation without destroying pending facts. Privileged provisioning/invitation/dispatch/consent/payment acceptance is online unless the canonical contract explicitly provides an offline intent.

Keep Flutter application/package boundaries. Use Firestore as the sole cloud database, SQLite locally and the approved free HTTPS/backend direction. No paid fallback, unrelated dependency, public sensitive credentials, fabricated production URL, blanket Firebase bypass or mocked operational success. New dependencies need a concrete task requirement and justification. Contract/API changes require coordinator review and aligned architecture/specification; ordinary workers cannot redefine ownership to avoid a blocker.

During feature construction run affected Flutter analysis, TypeScript build when touched and focused fast unit checks for authorization, money, durability or replay logic. Static analysis warnings/errors block local completion. A card's exact focused test path is allowed to be created; test meaningful policy/financial/retry boundaries, not a copy of the implementation. Existing equivalent focused tests may be reused when the coordinator updates the recorded command/path. Do not turn every UI task into a slow test suite. Full harness, comprehensive emulators and device acceptance occur in RELEASE after features are integrated, consistently with AGENTS.md. Documentation-only cards validate diffs/links; they do not require app rebuilds. Acceptance cards must execute their actual test/manual procedure, even when their only write is an evidence document.

Run commands from the repository root unless a command explicitly changes directory. Use the pinned toolchain and actual environment configuration. Commands with `/absolute/path/client.dev.json` require replacing that placeholder with an approved existing file; do not generate pretend credentials. Report pre-existing failures separately and never claim skipped commands passed. For newly created files, include an unstaged/no-index whitespace check because ordinary `git diff` does not include untracked files.

## Multiple terminals and integration ownership

Use one task branch/worktree per worker and one coordinator. Begin with two workers plus the coordinator; scale only when prerequisites and ownership are clear. The current workspace already contains unrelated changes. Worktrees start from commits, so first make a reviewed baseline containing the architecture and this guide plus any explicitly selected existing work. Do not commit all dirty files, stash another person's work, reset, clean or overwrite them to create a baseline. No such baseline commit is created by this documentation task.

Example terminal commands, after replacing `REVIEWED_BASELINE_COMMIT` with that reviewed commit:

```bash
git worktree add -b task/AUTH-03 /tmp/sarisupply-AUTH-03 REVIEWED_BASELINE_COMMIT
cd /tmp/sarisupply-AUTH-03
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only AUTH-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and prerequisite handoffs; do not read the entire guide.'
```

A second terminal uses a different branch/path and its task's model command. Copy only approved nonsecret configuration; never share a mutable local database or device identity between workers. Integrate prerequisite commits into the target baseline before creating dependent worktrees. Branch names do not grant authority to modify other tasks.

Coordinator owns this checklist, AGENTS.md, canonical architecture, CURRENT_STATE.md, shared manifest/dependency changes and schema-version allocation. Workers own their declared files and `docs/task-results/TASK-ID.md`. No two active tasks may share a write path, depend on each other, or independently change one schema/API contract. Claim shared command registries, package exports, app gates and local migration/version files exclusively, even when editing different lines. Run integration gates serially. Serialize shared emulator ports and build output directories; isolated worktrees still need distinct runtime ports/configuration.

Workers write a handoff with the goal, reused/replaced code, touched files, contract/version assumptions, exact verification results, manual steps/evidence, pending external gates, risks and next action. They do not edit the shared checklist. A coordinator integrates only reviewed task commits and resolves conflicts with current contracts. A `-90` reviewer is independent of feature authors; repairs go back to the original bounded feature scope. Do not merge or publish on behalf of the user without authorization applicable to that execution session.

The pairs below are examples, not blanket concurrency permission. Both tasks' prerequisites must be integrated into the same baseline, and their current allow-lists must still be disjoint. Recheck after any scope amendment.

| Group | Worker A | Worker B | Why safe under the declared scopes |
| --- | --- | --- | --- |
| P1 | [AUTH-03](#auth-03) | [AUTH-04](#auth-04) | Platform Admin entry and Store Owner entry have separate existing app/auth files. |
| P2 | [AUTH-07](#auth-07) | [AUTH-09](#auth-09) | Store Manager invitations and cashier sign-in use different service/adapter/screens; no shared gate changes. |
| P3 | [POS-04](#pos-04) | [PURCHASING-02](#purchasing-02) | Phone scanning and company supplier management own separate clients and domain files. |
| P4 | [REPORTS-09](#reports-09) | [RECOVERY-02](#recovery-02) | Report export implementation can run while printer hardware acceptance is documented. |
| P5 | [AUTH-14](#auth-14) | [SETUP-00](#setup-00) | Authorization UX and company setup contracts have separate document outputs after AUTH-01. |

Do not parallelize cashier enrollment with Store Manager invitation (shared management screen), catalog edits with opening stock (shared store/service), cash with QR checkout (shared payment/ledger), rider invite with staff removal (shared membership), or dispatch with Driver run work (shared delivery service). Concurrency comes from verified boundaries, not the number of terminals.

## Coverage and order

After authorization/setup/catalog, prioritize usable POS checkout. Retail operations and company purchasing can then progress along separate dependencies, followed by company order fulfillment/delivery/settlement, reporting/recovery and final release acceptance. Full customer-store receiving must wait for company delivery contracts so inventory never posts from proof alone.

| Group | Coverage | Independent gate |
| --- | --- | --- |
| [AUTH](#auth-tasks) | Google business login, company invitations, rider enrollment, cashier PIN/offline recovery, revocation and privacy. | [AUTH-90](#auth-90) |
| [SETUP](#setup-tasks) | Independent company/store ownership, warehouses, store approval, branches, customer relationship and device trust. | [SETUP-90](#setup-90) |
| [CATALOG](#catalog-tasks) | Owned catalogs, package/unit conversion, barcode, company-to-store mapping, photos, opening stock and delta sync. | [CATALOG-90](#catalog-90) |
| [POS](#pos-tasks) | Shifts, cart, phone scanning, cash/manual QR, durable receipts, cash movement, close/lock and outbox. | [POS-90](#pos-90) |
| [RETAIL](#retail-tasks) | Counts/adjustments, external receiving, batch/expiry, branch transfer, promotion, refund/void and customer credit. | [RETAIL-90](#retail-90) |
| [PURCHASING](#purchasing-tasks) | Supplier, purchase order, actual warehouse receipt, cost/stock posting, corrections and retry recovery. | [PURCHASING-90](#purchasing-90) |
| [ORDERS](#orders-tasks) | Revocable summaries, local restock draft, store confirmation, acceptance/amendment/cancellation and tracking. | [ORDERS-90](#orders-90) |
| [FULFILLMENT](#fulfillment-tasks) | Stock reservation, picking/shortage, immutable package manifest, release and bounded Operations queue. | [FULFILLMENT-90](#fulfillment-90) |
| [DELIVERY](#delivery-tasks) | Rider roster, run, company dispatch, assigned Driver work, navigation/proof/failure, retries and foreground location. | [DELIVERY-90](#delivery-90) |
| [SETTLEMENT](#settlement-tasks) | Store receipt/discrepancy, returned stock/disposition, rider collections/remittance and commercial payments. | [SETTLEMENT-90](#settlement-90) |
| [REPORTS](#reports-tasks) | Store versus company reports, costs/valuation, honest overview, consented insights, alerts and CSV. | [REPORTS-90](#reports-90) |
| [RECOVERY](#recovery-tasks) | One real printer transport, reprint, complete encrypted archive, verification, isolated restore, retention and diagnostics. | [RECOVERY-90](#recovery-90) |
| [RELEASE](#release-tasks) | Legacy-data rehearsal, full security/offline/harness/device acceptance, capacity, signing, runbooks, deployment and monitoring. | [RELEASE-90](#release-90) |

## Coordinator checklist

Status values: `planned`, `ready`, `working`, `needs_review`, `integrated`, `verified`, `blocked`. `ready` means all prerequisites are integrated. `integrated` means reviewed local code is merged into the baseline; `verified` additionally needs that task's manual/external acceptance. A blocked hardware gate need not prevent unrelated ready development, but all mandatory gates block final production readiness. Contract/manual cards also require evidence, not runtime code.

All existing features must be inspected before rebuilding. The initial status is scheduling metadata, not an assertion that existing code is absent. Only AUTH-01 starts ready. Record a handoff for verified reuse just as for new code.

| Task | Feature | Profile | Dependencies | Status | Manual/external acceptance |
| --- | --- | --- | --- | --- | --- |
| [AUTH-01](#auth-01) | Freeze authorization contexts and compatibility | SH | None | ready | pending |
| [AUTH-02](#auth-02) | Provision Company Owner and enter Company Operations | SH | [AUTH-01](#auth-01) | planned | pending |
| [AUTH-03](#auth-03) | Keep Platform Admin login separate | LM | [AUTH-01](#auth-01) | planned | pending |
| [AUTH-04](#auth-04) | Verify Store Owner entry and business selection | LH | [AUTH-01](#auth-01) | planned | pending |
| [AUTH-05](#auth-05) | Invite and accept a warehouse manager | SH | [AUTH-02](#auth-02), [SETUP-02](#setup-02) | planned | pending |
| [AUTH-06](#auth-06) | Invite and accept a rider | SH | [AUTH-05](#auth-05) | planned | pending |
| [AUTH-07](#auth-07) | Verify Store Manager invitation and scope | LH | [AUTH-04](#auth-04) | planned | pending |
| [AUTH-08](#auth-08) | Enroll a cashier and reset a temporary PIN | SM | [AUTH-04](#auth-04) | planned | pending |
| [AUTH-09](#auth-09) | Sign a cashier in and change the first PIN | SH | [AUTH-08](#auth-08) | planned | pending |
| [AUTH-10](#auth-10) | Recover an authorized cashier offline | SH | [AUTH-09](#auth-09) | planned | pending |
| [AUTH-11](#auth-11) | Remove company staff access | SH | [AUTH-06](#auth-06) | planned | pending |
| [AUTH-12](#auth-12) | Verify revoked-device startup recovery | SH | [AUTH-09](#auth-09) | planned | pending |
| [AUTH-13](#auth-13) | Close broad Platform Admin retail reads | SH | [AUTH-02](#auth-02), [AUTH-03](#auth-03), [AUTH-04](#auth-04) | planned | pending |
| [AUTH-14](#auth-14) | Lock authorization UX and role navigation | LM | [AUTH-01](#auth-01) | planned | pending |
| [AUTH-90](#auth-90) | Auth integration, review and usability acceptance | SH | [AUTH-01](#auth-01), [AUTH-02](#auth-02), [AUTH-03](#auth-03), [AUTH-04](#auth-04), [AUTH-05](#auth-05), [AUTH-06](#auth-06), [AUTH-07](#auth-07), [AUTH-08](#auth-08), [AUTH-09](#auth-09), [AUTH-10](#auth-10), [AUTH-11](#auth-11), [AUTH-12](#auth-12), [AUTH-13](#auth-13), [AUTH-14](#auth-14) | planned | pending |
| [SETUP-00](#setup-00) | Freeze company setup and commercial relationship contracts | SH | [AUTH-01](#auth-01) | planned | pending |
| [SETUP-01](#setup-01) | Maintain company business details | SM | [AUTH-02](#auth-02), [SETUP-00](#setup-00) | planned | pending |
| [SETUP-02](#setup-02) | Create and maintain a company warehouse | SM | [SETUP-01](#setup-01) | planned | pending |
| [SETUP-03](#setup-03) | Submit a store application | LH | [AUTH-04](#auth-04), [SETUP-00](#setup-00) | planned | pending |
| [SETUP-04](#setup-04) | Approve or reject a store application | SM | [AUTH-03](#auth-03), [SETUP-03](#setup-03) | planned | pending |
| [SETUP-05](#setup-05) | Maintain store branches | LH | [SETUP-04](#setup-04), [AUTH-07](#auth-07) | planned | pending |
| [SETUP-06](#setup-06) | Establish the company-to-store relationship | SH | [SETUP-01](#setup-01), [SETUP-04](#setup-04) | planned | pending |
| [SETUP-07](#setup-07) | Activate a branch-scoped POS device | SH | [SETUP-05](#setup-05), [AUTH-08](#auth-08) | planned | pending |
| [SETUP-08](#setup-08) | Manage device revocation and safe replacement | SH | [SETUP-07](#setup-07), [AUTH-12](#auth-12) | planned | pending |
| [SETUP-90](#setup-90) | Setup integration, review and usability acceptance | SH | [SETUP-01](#setup-01), [SETUP-02](#setup-02), [SETUP-03](#setup-03), [SETUP-04](#setup-04), [SETUP-05](#setup-05), [SETUP-06](#setup-06), [SETUP-07](#setup-07), [SETUP-08](#setup-08), [SETUP-00](#setup-00), [AUTH-90](#auth-90) | planned | pending |
| [CATALOG-01](#catalog-01) | Freeze company/store catalog and stock contracts | SH | [AUTH-01](#auth-01), [SETUP-06](#setup-06), [SETUP-90](#setup-90) | planned | pending |
| [CATALOG-02](#catalog-02) | Create and edit a store retail product | SM | [CATALOG-01](#catalog-01), [SETUP-07](#setup-07) | planned | pending |
| [CATALOG-03](#catalog-03) | Configure retail sale units and barcodes | SH | [CATALOG-02](#catalog-02) | planned | pending |
| [CATALOG-04](#catalog-04) | Maintain the company wholesale catalog | SM | [CATALOG-01](#catalog-01), [SETUP-02](#setup-02) | planned | pending |
| [CATALOG-05](#catalog-05) | Map a company product to a store product | SH | [CATALOG-03](#catalog-03), [CATALOG-04](#catalog-04), [SETUP-06](#setup-06) | planned | pending |
| [CATALOG-06](#catalog-06) | Capture, replace and remove a retail product photo | LH | [CATALOG-02](#catalog-02) | planned | pending |
| [CATALOG-07](#catalog-07) | Search and browse branch stock | LM | [CATALOG-03](#catalog-03) | planned | pending |
| [CATALOG-08](#catalog-08) | Record opening stock once | SH | [CATALOG-02](#catalog-02), [SETUP-07](#setup-07) | planned | pending |
| [CATALOG-09](#catalog-09) | Reconcile inventory deltas on reconnect | SH | [CATALOG-08](#catalog-08) | planned | pending |
| [CATALOG-90](#catalog-90) | Catalog integration, review and usability acceptance | SH | [CATALOG-01](#catalog-01), [CATALOG-02](#catalog-02), [CATALOG-03](#catalog-03), [CATALOG-04](#catalog-04), [CATALOG-05](#catalog-05), [CATALOG-06](#catalog-06), [CATALOG-07](#catalog-07), [CATALOG-08](#catalog-08), [CATALOG-09](#catalog-09) | planned | pending |
| [POS-01](#pos-01) | Freeze the cashier checkout contract | SH | [AUTH-09](#auth-09), [CATALOG-09](#catalog-09), [SETUP-07](#setup-07), [CATALOG-90](#catalog-90) | planned | pending |
| [POS-02](#pos-02) | Open a cashier shift with float | SH | [POS-01](#pos-01) | planned | pending |
| [POS-03](#pos-03) | Build and resume a cart from search | LH | [POS-02](#pos-02), [CATALOG-07](#catalog-07) | planned | pending |
| [POS-04](#pos-04) | Scan a product with the rear camera | LM | [POS-03](#pos-03), [CATALOG-03](#catalog-03) | planned | pending |
| [POS-05](#pos-05) | Complete a cash sale with exact change | SH | [POS-03](#pos-03) | planned | pending |
| [POS-06](#pos-06) | Record a manually confirmed QR sale | SH | [POS-05](#pos-05) | planned | pending |
| [POS-07](#pos-07) | Show and recover an immutable receipt | LH | [POS-05](#pos-05), [POS-06](#pos-06) | planned | pending |
| [POS-08](#pos-08) | Record cashier cash-in or cash-out | SH | [POS-02](#pos-02) | planned | pending |
| [POS-09](#pos-09) | Close a shift and record discrepancy | SH | [POS-05](#pos-05), [POS-06](#pos-06), [POS-08](#pos-08) | planned | pending |
| [POS-10](#pos-10) | Lock checkout without losing business work | LH | [POS-07](#pos-07), [AUTH-09](#auth-09) | planned | pending |
| [POS-11](#pos-11) | Synchronize checkout with bounded replay | SH | [POS-07](#pos-07), [POS-09](#pos-09) | planned | pending |
| [POS-90](#pos-90) | Pos integration, review and usability acceptance | SH | [POS-01](#pos-01), [POS-02](#pos-02), [POS-03](#pos-03), [POS-04](#pos-04), [POS-05](#pos-05), [POS-06](#pos-06), [POS-07](#pos-07), [POS-08](#pos-08), [POS-09](#pos-09), [POS-10](#pos-10), [POS-11](#pos-11) | planned | pending |
| [RETAIL-01](#retail-01) | Freeze retail adjustment and credit contracts | SH | [POS-11](#pos-11), [POS-90](#pos-90) | planned | pending |
| [RETAIL-02](#retail-02) | Record a physical stock count | SH | [RETAIL-01](#retail-01) | planned | pending |
| [RETAIL-03](#retail-03) | Record a reasoned retail stock adjustment | SH | [RETAIL-02](#retail-02) | planned | pending |
| [RETAIL-04](#retail-04) | Receive external retail stock into a branch | SH | [RETAIL-01](#retail-01), [CATALOG-05](#catalog-05) | planned | pending |
| [RETAIL-05](#retail-05) | Track batches and expiry at receiving | SM | [RETAIL-04](#retail-04) | planned | pending |
| [RETAIL-06](#retail-06) | Dispatch a same-store branch transfer | SH | [RETAIL-01](#retail-01), [SETUP-05](#setup-05) | planned | pending |
| [RETAIL-07](#retail-07) | Receive a branch transfer partially or fully | SH | [RETAIL-06](#retail-06) | planned | pending |
| [RETAIL-08](#retail-08) | Configure and apply a scoped promotion | SH | [RETAIL-01](#retail-01), [POS-05](#pos-05) | planned | pending |
| [RETAIL-09](#retail-09) | Refund exact receipt lines with Owner approval | SH | [RETAIL-01](#retail-01), [POS-07](#pos-07) | planned | pending |
| [RETAIL-10](#retail-10) | Void an eligible sale with exact approval | SH | [RETAIL-09](#retail-09) | planned | pending |
| [RETAIL-11](#retail-11) | Manage a retail customer credit account | SM | [RETAIL-01](#retail-01) | planned | pending |
| [RETAIL-12](#retail-12) | Reserve and consume offline customer allowance | SH | [RETAIL-11](#retail-11), [POS-11](#pos-11) | planned | pending |
| [RETAIL-13](#retail-13) | Record and synchronize a customer repayment | SH | [RETAIL-12](#retail-12) | planned | pending |
| [RETAIL-90](#retail-90) | Retail integration, review and usability acceptance | SH | [RETAIL-01](#retail-01), [RETAIL-02](#retail-02), [RETAIL-03](#retail-03), [RETAIL-04](#retail-04), [RETAIL-05](#retail-05), [RETAIL-06](#retail-06), [RETAIL-07](#retail-07), [RETAIL-08](#retail-08), [RETAIL-09](#retail-09), [RETAIL-10](#retail-10), [RETAIL-11](#retail-11), [RETAIL-12](#retail-12), [RETAIL-13](#retail-13) | planned | pending |
| [PURCHASING-01](#purchasing-01) | Freeze company purchasing contracts | SH | [AUTH-01](#auth-01), [SETUP-02](#setup-02), [CATALOG-04](#catalog-04), [CATALOG-90](#catalog-90) | planned | pending |
| [PURCHASING-02](#purchasing-02) | Manage the upstream supplier directory | SM | [PURCHASING-01](#purchasing-01) | planned | pending |
| [PURCHASING-03](#purchasing-03) | Issue a company supplier purchase order | SH | [PURCHASING-02](#purchasing-02) | planned | pending |
| [PURCHASING-04](#purchasing-04) | Receive a supplier PO partially | SH | [PURCHASING-03](#purchasing-03) | planned | pending |
| [PURCHASING-05](#purchasing-05) | Review company warehouse stock and costs | SM | [PURCHASING-04](#purchasing-04) | planned | pending |
| [PURCHASING-06](#purchasing-06) | Correct company warehouse stock with a reason | SH | [PURCHASING-05](#purchasing-05) | planned | pending |
| [PURCHASING-07](#purchasing-07) | Recover a pending company purchase operation | SH | [PURCHASING-06](#purchasing-06) | planned | pending |
| [PURCHASING-90](#purchasing-90) | Purchasing integration, review and usability acceptance | SH | [PURCHASING-01](#purchasing-01), [PURCHASING-02](#purchasing-02), [PURCHASING-03](#purchasing-03), [PURCHASING-04](#purchasing-04), [PURCHASING-05](#purchasing-05), [PURCHASING-06](#purchasing-06), [PURCHASING-07](#purchasing-07) | planned | pending |
| [ORDERS-01](#orders-01) | Freeze independent-store order contracts | SH | [CATALOG-05](#catalog-05), [PURCHASING-05](#purchasing-05), [SETUP-06](#setup-06), [PURCHASING-90](#purchasing-90) | planned | pending |
| [ORDERS-02](#orders-02) | Control replenishment-summary sharing | SH | [ORDERS-01](#orders-01), [AUTH-13](#auth-13) | planned | pending |
| [ORDERS-03](#orders-03) | Draft suggested replenishment quantities | LH | [ORDERS-01](#orders-01), [CATALOG-09](#catalog-09) | planned | pending |
| [ORDERS-04](#orders-04) | Confirm and submit a store purchase | SH | [ORDERS-03](#orders-03) | planned | pending |
| [ORDERS-05](#orders-05) | Accept or reject an order in Operations | SH | [ORDERS-04](#orders-04) | planned | pending |
| [ORDERS-06](#orders-06) | Propose and reconfirm an order amendment | SH | [ORDERS-05](#orders-05) | planned | pending |
| [ORDERS-07](#orders-07) | Cancel an eligible confirmed order | SH | [ORDERS-06](#orders-06) | planned | pending |
| [ORDERS-08](#orders-08) | Track a store order and its delivery state | LM | [ORDERS-05](#orders-05), [ORDERS-07](#orders-07) | planned | pending |
| [ORDERS-90](#orders-90) | Orders integration, review and usability acceptance | SH | [ORDERS-01](#orders-01), [ORDERS-02](#orders-02), [ORDERS-03](#orders-03), [ORDERS-04](#orders-04), [ORDERS-05](#orders-05), [ORDERS-06](#orders-06), [ORDERS-07](#orders-07), [ORDERS-08](#orders-08) | planned | pending |
| [FULFILLMENT-01](#fulfillment-01) | Freeze warehouse fulfillment contracts | SH | [ORDERS-06](#orders-06), [PURCHASING-07](#purchasing-07), [ORDERS-90](#orders-90) | planned | pending |
| [FULFILLMENT-02](#fulfillment-02) | Reserve company stock for an accepted order | SH | [FULFILLMENT-01](#fulfillment-01) | planned | pending |
| [FULFILLMENT-03](#fulfillment-03) | Pick accepted order quantities | SH | [FULFILLMENT-02](#fulfillment-02) | planned | pending |
| [FULFILLMENT-04](#fulfillment-04) | Pack identifiable order packages | SH | [FULFILLMENT-03](#fulfillment-03) | planned | pending |
| [FULFILLMENT-05](#fulfillment-05) | Release unshipped fulfillment work safely | SH | [FULFILLMENT-04](#fulfillment-04), [ORDERS-07](#orders-07) | planned | pending |
| [FULFILLMENT-06](#fulfillment-06) | Use the company fulfillment queue | LM | [FULFILLMENT-04](#fulfillment-04), [FULFILLMENT-05](#fulfillment-05) | planned | pending |
| [FULFILLMENT-90](#fulfillment-90) | Fulfillment integration, review and usability acceptance | SH | [FULFILLMENT-01](#fulfillment-01), [FULFILLMENT-02](#fulfillment-02), [FULFILLMENT-03](#fulfillment-03), [FULFILLMENT-04](#fulfillment-04), [FULFILLMENT-05](#fulfillment-05), [FULFILLMENT-06](#fulfillment-06) | planned | pending |
| [DELIVERY-01](#delivery-01) | Freeze company delivery and proof contracts | SH | [FULFILLMENT-04](#fulfillment-04), [AUTH-06](#auth-06), [FULFILLMENT-90](#fulfillment-90) | planned | pending |
| [DELIVERY-02](#delivery-02) | Select an active scoped rider from the roster | LH | [DELIVERY-01](#delivery-01), [AUTH-11](#auth-11) | planned | pending |
| [DELIVERY-03](#delivery-03) | Create a draft run from packed manifests | SH | [DELIVERY-02](#delivery-02), [FULFILLMENT-06](#fulfillment-06) | planned | pending |
| [DELIVERY-04](#delivery-04) | Dispatch a verified company run | SH | [DELIVERY-03](#delivery-03) | planned | pending |
| [DELIVERY-05](#delivery-05) | Load assigned runs in Driver | SM | [DELIVERY-04](#delivery-04) | planned | pending |
| [DELIVERY-06](#delivery-06) | Navigate and record arrival at a stop | LH | [DELIVERY-05](#delivery-05) | planned | pending |
| [DELIVERY-07](#delivery-07) | Record actual delivery quantities and proof | SH | [DELIVERY-06](#delivery-06) | planned | pending |
| [DELIVERY-08](#delivery-08) | Record failure and structured return reasons | SH | [DELIVERY-07](#delivery-07) | planned | pending |
| [DELIVERY-09](#delivery-09) | Synchronize durable Driver events | SH | [DELIVERY-08](#delivery-08) | planned | pending |
| [DELIVERY-10](#delivery-10) | Share location explicitly while foregrounded | LH | [DELIVERY-05](#delivery-05) | planned | pending |
| [DELIVERY-11](#delivery-11) | View the latest permitted rider location | SM | [DELIVERY-10](#delivery-10), [DELIVERY-04](#delivery-04) | planned | pending |
| [DELIVERY-90](#delivery-90) | Delivery integration, review and usability acceptance | SH | [DELIVERY-01](#delivery-01), [DELIVERY-02](#delivery-02), [DELIVERY-03](#delivery-03), [DELIVERY-04](#delivery-04), [DELIVERY-05](#delivery-05), [DELIVERY-06](#delivery-06), [DELIVERY-07](#delivery-07), [DELIVERY-08](#delivery-08), [DELIVERY-09](#delivery-09), [DELIVERY-10](#delivery-10), [DELIVERY-11](#delivery-11) | planned | pending |
| [SETTLEMENT-01](#settlement-01) | Freeze independent receiving and settlement contracts | SH | [DELIVERY-09](#delivery-09), [FULFILLMENT-01](#fulfillment-01), [DELIVERY-90](#delivery-90) | planned | pending |
| [SETTLEMENT-02](#settlement-02) | Confirm actual company-order goods in POS | SH | [SETTLEMENT-01](#settlement-01) | planned | pending |
| [SETTLEMENT-03](#settlement-03) | Open and resolve a delivery discrepancy | SH | [SETTLEMENT-02](#settlement-02) | planned | pending |
| [SETTLEMENT-04](#settlement-04) | Receive returned goods at the warehouse | SH | [SETTLEMENT-01](#settlement-01), [DELIVERY-08](#delivery-08) | planned | pending |
| [SETTLEMENT-05](#settlement-05) | Restock or quarantine received returns | SH | [SETTLEMENT-04](#settlement-04) | planned | pending |
| [SETTLEMENT-06](#settlement-06) | Record and review rider cash collection | SH | [SETTLEMENT-01](#settlement-01), [DELIVERY-07](#delivery-07) | planned | pending |
| [SETTLEMENT-07](#settlement-07) | Confirm rider cash remittance | SH | [SETTLEMENT-06](#settlement-06) | planned | pending |
| [SETTLEMENT-08](#settlement-08) | Reconcile company order payment evidence | SH | [SETTLEMENT-02](#settlement-02), [SETTLEMENT-06](#settlement-06), [SETTLEMENT-07](#settlement-07) | planned | pending |
| [SETTLEMENT-90](#settlement-90) | Settlement integration, review and usability acceptance | SH | [SETTLEMENT-01](#settlement-01), [SETTLEMENT-02](#settlement-02), [SETTLEMENT-03](#settlement-03), [SETTLEMENT-04](#settlement-04), [SETTLEMENT-05](#settlement-05), [SETTLEMENT-06](#settlement-06), [SETTLEMENT-07](#settlement-07), [SETTLEMENT-08](#settlement-08) | planned | pending |
| [REPORTS-01](#reports-01) | Freeze reporting scopes and sources | SH | [POS-11](#pos-11), [SETTLEMENT-08](#settlement-08), [ORDERS-02](#orders-02), [SETTLEMENT-90](#settlement-90) | planned | pending |
| [REPORTS-02](#reports-02) | Show branch and store retail sales reports | SH | [REPORTS-01](#reports-01) | planned | pending |
| [REPORTS-03](#reports-03) | Show an honest Store Owner overview | LM | [REPORTS-02](#reports-02) | planned | pending |
| [REPORTS-04](#reports-04) | Show company wholesale sales and settlement reports | SH | [REPORTS-01](#reports-01) | planned | pending |
| [REPORTS-05](#reports-05) | Show inventory valuation with missing-cost states | SH | [REPORTS-02](#reports-02), [REPORTS-04](#reports-04), [PURCHASING-05](#purchasing-05) | planned | pending |
| [REPORTS-06](#reports-06) | Show consented replenishment insights | SH | [REPORTS-01](#reports-01), [ORDERS-02](#orders-02) | planned | pending |
| [REPORTS-07](#reports-07) | Show actionable store stock and sync alerts | LH | [RETAIL-05](#retail-05), [CATALOG-09](#catalog-09), [POS-11](#pos-11) | planned | pending |
| [REPORTS-08](#reports-08) | Show scoped company operations alerts | SM | [FULFILLMENT-06](#fulfillment-06), [SETTLEMENT-07](#settlement-07) | planned | pending |
| [REPORTS-09](#reports-09) | Export scoped reports as real files | LH | [REPORTS-02](#reports-02), [REPORTS-04](#reports-04), [REPORTS-05](#reports-05) | planned | pending |
| [REPORTS-90](#reports-90) | Reports integration, review and usability acceptance | SH | [REPORTS-01](#reports-01), [REPORTS-02](#reports-02), [REPORTS-03](#reports-03), [REPORTS-04](#reports-04), [REPORTS-05](#reports-05), [REPORTS-06](#reports-06), [REPORTS-07](#reports-07), [REPORTS-08](#reports-08), [REPORTS-09](#reports-09) | planned | pending |
| [RECOVERY-01](#recovery-01) | Freeze archive, recovery and printer contracts | SH | [POS-11](#pos-11), [SETTLEMENT-08](#settlement-08), [REPORTS-01](#reports-01), [SETTLEMENT-90](#settlement-90) | planned | pending |
| [RECOVERY-02](#recovery-02) | Record and validate the real printer hardware | LM | [RECOVERY-01](#recovery-01) | planned | pending |
| [RECOVERY-03](#recovery-03) | Configure and print through one real transport | SM | [RECOVERY-02](#recovery-02), [POS-07](#pos-07) | planned | pending |
| [RECOVERY-04](#recovery-04) | Reprint a receipt or closed-shift summary | LM | [RECOVERY-03](#recovery-03), [POS-09](#pos-09) | planned | pending |
| [RECOVERY-05](#recovery-05) | Export a complete encrypted business archive | SH | [RECOVERY-01](#recovery-01), [SETTLEMENT-08](#settlement-08) | planned | pending |
| [RECOVERY-06](#recovery-06) | Verify an archive before restoring it | SH | [RECOVERY-05](#recovery-05) | planned | pending |
| [RECOVERY-07](#recovery-07) | Restore into an isolated empty workspace | SH | [RECOVERY-06](#recovery-06) | planned | pending |
| [RECOVERY-08](#recovery-08) | Archive settled records before retention deletion | SH | [RECOVERY-05](#recovery-05), [REPORTS-09](#reports-09) | planned | pending |
| [RECOVERY-09](#recovery-09) | Inspect blocked local work without losing it | LH | [POS-11](#pos-11), [ORDERS-08](#orders-08), [DELIVERY-09](#delivery-09) | planned | pending |
| [RECOVERY-90](#recovery-90) | Recovery integration, review and usability acceptance | SH | [RECOVERY-01](#recovery-01), [RECOVERY-02](#recovery-02), [RECOVERY-03](#recovery-03), [RECOVERY-04](#recovery-04), [RECOVERY-05](#recovery-05), [RECOVERY-06](#recovery-06), [RECOVERY-07](#recovery-07), [RECOVERY-08](#recovery-08), [RECOVERY-09](#recovery-09) | planned | pending |
| [RELEASE-01](#release-01) | Freeze final acceptance and release evidence | SH | [RECOVERY-01](#recovery-01) | planned | pending |
| [RELEASE-02](#release-02) | Dry-run the legacy architecture migration | SH | [RELEASE-01](#release-01), [RECOVERY-06](#recovery-06) | planned | pending |
| [RELEASE-03](#release-03) | Rehearse and validate data-preserving migration | SH | [RELEASE-02](#release-02), [RECOVERY-07](#recovery-07), [RETAIL-90](#retail-90), [REPORTS-90](#reports-90), [RECOVERY-90](#recovery-90) | planned | pending |
| [RELEASE-04](#release-04) | Run final role and tenancy security acceptance | SH | [RELEASE-03](#release-03) | planned | pending |
| [RELEASE-05](#release-05) | Run final offline, replay and crash acceptance | SH | [RELEASE-03](#release-03) | planned | pending |
| [RELEASE-06](#release-06) | Run full harness and matching client builds | SM | [RELEASE-04](#release-04), [RELEASE-05](#release-05) | planned | pending |
| [RELEASE-07](#release-07) | Accept all actor workflows on actual devices | SM | [RELEASE-06](#release-06), [RECOVERY-03](#recovery-03) | planned | pending |
| [RELEASE-08](#release-08) | Measure free-tier capacity and query indexes | SH | [RELEASE-06](#release-06) | planned | pending |
| [RELEASE-09](#release-09) | Prepare and verify signed production artifacts | SM | [RELEASE-07](#release-07), [RELEASE-08](#release-08) | planned | pending |
| [RELEASE-10](#release-10) | Correct operator and disaster-recovery runbooks | LH | [RELEASE-07](#release-07), [RELEASE-08](#release-08), [RECOVERY-08](#recovery-08) | planned | pending |
| [RELEASE-11](#release-11) | Prepare controlled deployment and rollback | SM | [RELEASE-09](#release-09), [RELEASE-10](#release-10) | planned | pending |
| [RELEASE-12](#release-12) | Verify monitoring and recovery readiness | SM | [RELEASE-11](#release-11) | planned | pending |
| [RELEASE-90](#release-90) | Release integration, review and usability acceptance | SH | [RELEASE-01](#release-01), [RELEASE-02](#release-02), [RELEASE-03](#release-03), [RELEASE-04](#release-04), [RELEASE-05](#release-05), [RELEASE-06](#release-06), [RELEASE-07](#release-07), [RELEASE-08](#release-08), [RELEASE-09](#release-09), [RELEASE-10](#release-10), [RELEASE-11](#release-11), [RELEASE-12](#release-12) | planned | pending |

<a id="auth-tasks"></a>

## AUTH: Authorization and login

<a id="auth-01"></a>

### AUTH-01 — Freeze authorization contexts and compatibility

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** None

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-01: Freeze authorization contexts and compatibility.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: None. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define company versus store principals, verified role/warehouse/branch scope, invitation lifecycle, resource ownership, typed workspace responses, audit attribution and old-client behavior. Specify additive schema/API contracts and explicit legacy mapping; include an actor/action denial matrix.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/authorization.md [planned]
- docs/task-results/AUTH-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No runtime edits, automatic owner promotion, blanket Platform Admin data access, or live data migration.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/authorization.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace every canonical actor through sign-in, permitted action, denial and reconnect; identify evidence for reuse.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-02"></a>

### AUTH-02 — Provision Company Owner and enter Company Operations

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-02: Provision Company Owner and enter Company Operations.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Implement trusted Company Owner provisioning and Google-authenticated company entry. Verify active company membership server-side, show no-access recovery, and keep platform authority separate; provisioning retries cannot duplicate or elevate another user.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/common/authz.ts [existing]
- firebase/functions/src/company/company-owner-service.ts [planned]
- firebase/functions/src/admin/grant-company-owner.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_functions.dart [planned]
- packages/sarisupply_models/lib/src/company/identity.dart [planned]
- packages/sarisupply_auth/lib/src/company_repository.dart [planned]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/admin/lib/features/company/company_entry_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- firebase/functions/test/tasks/auth_02.test.ts [planned]
- docs/task-results/AUTH-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No public owner signup, credential sharing, store ownership reassignment, invitations or operational dashboard statistics.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/auth_02.test.ts
git diff --check -- firebase/functions/src/common/authz.ts firebase/functions/src/company/company-owner-service.ts firebase/functions/src/admin/grant-company-owner.ts packages/sarisupply_firebase/lib/src/functions/company_functions.dart packages/sarisupply_models/lib/src/company/identity.dart packages/sarisupply_auth/lib/src/company_repository.dart apps/admin/lib/app/admin_app_gate.dart apps/admin/lib/features/company/company_entry_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_auth/lib/sarisupply_auth.dart

Manual checks / observable acceptance:
Provision a Development owner with approved credentials; verify nonmember denial, selected-company context and sign-out.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-03"></a>

### AUTH-03 — Keep Platform Admin login separate

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** AUTH-01

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only AUTH-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-03: Keep Platform Admin login separate.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: AUTH-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Verify Google sign-in plus current platform claim/record, keep platform review access separate from company membership, and show safe pending/denied states. Preserve cancellation and sign-out recovery.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/admin_auth/presentation/admin_auth_gate.dart [existing]
- packages/sarisupply_firebase/lib/src/auth/firebase_admin_access_repository.dart [existing]
- docs/task-results/AUTH-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No company membership grants, tenant sales access, backend role redesign or shared Google adapter changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
git diff --check -- apps/admin/lib/features/admin_auth/presentation/admin_auth_gate.dart packages/sarisupply_firebase/lib/src/auth/firebase_admin_access_repository.dart

Manual checks / observable acceptance:
Use active platform admin and ordinary account; cancel sign-in and sign out without leaving child routes visible.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-04"></a>

### AUTH-04 — Verify Store Owner entry and business selection

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-01

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-04: Verify Store Owner entry and business selection.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: AUTH-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Preserve store membership checks, pending application states and branch/device context; select a business only among current memberships. Never infer company ownership from a store owner role; dispose stale child screens on context change.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/pos/lib/app/firebase_pos_workflow.dart [existing]
- apps/pos/lib/features/owner_onboarding/presentation/owner_onboarding_gate.dart [existing]
- packages/sarisupply_auth/lib/src/merchant_context.dart [existing]
- docs/task-results/AUTH-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No company provisioning, cashier credential changes, inventory deletion or navigation redesign.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
git diff --check -- apps/pos/lib/app/pos_app_gate.dart apps/pos/lib/app/firebase_pos_workflow.dart apps/pos/lib/features/owner_onboarding/presentation/owner_onboarding_gate.dart packages/sarisupply_auth/lib/src/merchant_context.dart

Manual checks / observable acceptance:
Test no membership, one store, multiple stores, denied refresh and logout with pending local records retained.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-05"></a>

### AUTH-05 — Invite and accept a warehouse manager

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-02, SETUP-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-05: Invite and accept a warehouse manager.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-02, SETUP-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner invites a Google email with warehouse scope; matching recipient accepts once and enters scoped Operations. Store managers and warehouse managers cannot invite/elevate staff; expired or mismatched invitations fail safely.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/company-membership-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart [planned]
- apps/admin/lib/features/company/company_team_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/invitation.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/auth_05.test.ts [planned]
- docs/task-results/AUTH-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No rider invitation, arbitrary role input, owner transfer, bulk team changes or offline acceptance.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/auth_05.test.ts
git diff --check -- firebase/functions/src/company/company-membership-service.ts packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart apps/admin/lib/features/company/company_team_screen.dart packages/sarisupply_models/lib/src/company/invitation.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Invite one manager, accept with matching account, reject wrong account and confirm other warehouses are inaccessible.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-06"></a>

### AUTH-06 — Invite and accept a rider

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-06: Invite and accept a rider.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner invites a verified Google identity with warehouse scope; Driver accepts and discovers its active company workspace. Remove manual UID exchange from this enrollment path; sign-in alone grants nothing and replay cannot duplicate membership.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/company-membership-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart [planned]
- apps/admin/lib/features/company/company_team_screen.dart [planned]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- apps/driver/lib/features/enrollment/rider_invitation_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/auth_06.test.ts [planned]
- docs/task-results/AUTH-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No dispatch, route creation, raw-ID onboarding fallback, background location or store-owner rider enrollment.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/auth_06.test.ts
git diff --check -- firebase/functions/src/company/company-membership-service.ts packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart apps/admin/lib/features/company/company_team_screen.dart apps/driver/lib/app/driver_app_gate.dart apps/driver/lib/features/enrollment/rider_invitation_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Accept a rider invite on Driver; verify wrong email, expiry, cancelled invite, no-workspace recovery and logout.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-07"></a>

### AUTH-07 — Verify Store Manager invitation and scope

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-04

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-07: Verify Store Manager invitation and scope.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: AUTH-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Reuse Store Owner email invitations with existing branch-scoped acceptance; show store identity and permitted branches. Reject owner escalation and unauthorized branch access without introducing company permissions.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/membership/membership-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/membership_functions.dart [existing]
- apps/pos/lib/features/management/presentation/management_screen.dart [existing]
- docs/task-results/AUTH-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No company staff roles, shared auth policy edits, device provisioning or cashier enrollment.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/membership/membership-service.ts packages/sarisupply_firebase/lib/src/functions/membership_functions.dart apps/pos/lib/features/management/presentation/management_screen.dart

Manual checks / observable acceptance:
Invite a manager for one branch, accept once and verify another branch is denied.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-08"></a>

### AUTH-08 — Enroll a cashier and reset a temporary PIN

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** AUTH-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only AUTH-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-08: Enroll a cashier and reset a temporary PIN.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: AUTH-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized store management creates a named cashier and branch assignment with retry-safe creation, suspension/reset controls and mandatory temporary-PIN change. Preserve server PIN hashing and never return/persist plaintext beyond transient entry.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/cashier/cashier-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/cashier_functions.dart [existing]
- apps/pos/lib/features/management/presentation/management_screen.dart [existing]
- firebase/functions/test/tasks/auth_08.test.ts [planned]
- docs/task-results/AUTH-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No Google account requirement for cashiers, company employment, PIN algorithm replacement or offline enrollment.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/auth_08.test.ts
git diff --check -- firebase/functions/src/cashier/cashier-service.ts packages/sarisupply_firebase/lib/src/functions/cashier_functions.dart apps/pos/lib/features/management/presentation/management_screen.dart

Manual checks / observable acceptance:
Create a cashier, retry creation, suspend it and reset a PIN; verify unassigned manager denial and no secret in roster responses.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-09"></a>

### AUTH-09 — Sign a cashier in and change the first PIN

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-09: Sign a cashier in and change the first PIN.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Implement named roster selection, online PIN verification and first-use permanent PIN change; only a current branch/device grant opens Checkout. Clear transient PIN input on failure and preserve legitimate local business data.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/cashier_auth/domain/cashier_login_service.dart [existing]
- apps/pos/lib/features/cashier_auth/presentation/cashier_login_screen.dart [existing]
- apps/pos/lib/features/cashier_auth/presentation/change_temporary_pin_screen.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/cashier_functions.dart [existing]
- apps/pos/test/tasks/auth_09_test.dart [planned]
- docs/task-results/AUTH-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No weak verifier fallback, device context changes, company login or automatic shift opening.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd apps/pos && flutter test test/tasks/auth_09_test.dart)
git diff --check -- apps/pos/lib/features/cashier_auth/domain/cashier_login_service.dart apps/pos/lib/features/cashier_auth/presentation/cashier_login_screen.dart apps/pos/lib/features/cashier_auth/presentation/change_temporary_pin_screen.dart packages/sarisupply_firebase/lib/src/functions/cashier_functions.dart

Manual checks / observable acceptance:
Try wrong PIN, required change, successful change, suspended cashier and retry after network failure.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-10"></a>

### AUTH-10 — Recover an authorized cashier offline

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-10 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-10: Recover an authorized cashier offline.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Preserve encrypted verifier/grant storage, seven-day same-boot monotonic checks, failure cooldown and durable PIN audit upload. Reboot, missing clock evidence and observed revocation fail closed without deleting queued business facts.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/cashier_auth/domain/cashier_login_service.dart [existing]
- apps/pos/lib/features/cashier_auth/data/secure_offline_credential_store.dart [existing]
- packages/sarisupply_auth/lib/src/offline/offline_credential_policy.dart [existing]
- apps/pos/lib/app/firebase_pos_workflow.dart [existing]
- apps/pos/test/tasks/auth_10_test.dart [planned]
- docs/task-results/AUTH-10.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No longer offline window, clock-only authorization, plaintext secrets or SQL credential storage.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd apps/pos && flutter test test/tasks/auth_10_test.dart)
git diff --check -- apps/pos/lib/features/cashier_auth/domain/cashier_login_service.dart apps/pos/lib/features/cashier_auth/data/secure_offline_credential_store.dart packages/sarisupply_auth/lib/src/offline/offline_credential_policy.dart apps/pos/lib/app/firebase_pos_workflow.dart

Manual checks / observable acceptance:
Enroll online, disconnect, recover, then verify expiry/reboot denial and retry-safe reconnect audit upload.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-10.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-11"></a>

### AUTH-11 — Remove company staff access

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-11 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-11: Remove company staff access.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner removes a manager or rider; server-sensitive actions recheck current status and warehouse scope. Clear observed access caches and close privileged child routes while preserving pending delivery evidence for explicit resolution.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/company-membership-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart [planned]
- apps/admin/lib/features/company/company_team_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/invitation.dart [planned]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- apps/driver/lib/features/enrollment/rider_invitation_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/auth_11.test.ts [planned]
- docs/task-results/AUTH-11.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No reassignment or silent discard of existing runs/proofs, staff-managed elevation or client-only revocation.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/auth_11.test.ts
git diff --check -- firebase/functions/src/company/company-membership-service.ts packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart apps/admin/lib/features/company/company_team_screen.dart packages/sarisupply_models/lib/src/company/invitation.dart apps/driver/lib/app/driver_app_gate.dart apps/driver/lib/features/enrollment/rider_invitation_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Remove an active rider/manager, reconnect their app and verify new work is blocked with pending evidence retained.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-11.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-12"></a>

### AUTH-12 — Verify revoked-device startup recovery

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-12 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-12: Verify revoked-device startup recovery.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Device bootstrap checks authoritative store/branch/device status; denied access clears authorization material and returns to safe recovery while retaining local ledger/outboxes. Retryable transport failure may use only valid cached context.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/device/device-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/device_functions.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/pos/lib/features/device_setup/presentation/device_setup_screen.dart [existing]
- firebase/functions/test/tasks/auth_12.test.ts [planned]
- docs/task-results/AUTH-12.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No device reassignment, business-data reset, bypassed App Check or treating server denial as offline permission.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/auth_12.test.ts
git diff --check -- firebase/functions/src/device/device-service.ts packages/sarisupply_firebase/lib/src/functions/device_functions.dart apps/pos/lib/app/pos_app_gate.dart apps/pos/lib/features/device_setup/presentation/device_setup_screen.dart

Manual checks / observable acceptance:
Revoke a Development device, refresh, disconnect and confirm it cannot regain checkout; verify ordinary outage retains valid work.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-12.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-13"></a>

### AUTH-13 — Close broad Platform Admin retail reads

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-02, AUTH-03, AUTH-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-13 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-13: Close broad Platform Admin retail reads.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-02, AUTH-03, AUTH-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Restrict operational report reads by business authority; Platform Admin alone cannot read independent-store retail data. Company responses exclude raw retail records; unavailable authorized summaries show an honest state until consent features exist.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/management/operations-read-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/operations_functions.dart [existing]
- apps/admin/lib/features/reports/presentation/admin_reports_screen.dart [existing]
- firebase/functions/test/tasks/auth_13.test.ts [planned]
- docs/task-results/AUTH-13.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No implicit sharing consent, fake totals, company-wide authority for managers or restoring broad access for UI convenience.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/auth_13.test.ts
git diff --check -- firebase/functions/src/management/operations-read-service.ts packages/sarisupply_firebase/lib/src/functions/operations_functions.dart apps/admin/lib/features/reports/presentation/admin_reports_screen.dart

Manual checks / observable acceptance:
Check platform-only admin, Company Owner, Store Owner and unrelated identity; confirm legacy read actions cannot bypass the policy.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-13.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-14"></a>

### AUTH-14 — Lock authorization UX and role navigation

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** contract · **Dependencies:** AUTH-01

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only AUTH-14 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-14: Lock authorization UX and role navigation.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: AUTH-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Document login/invitation/denied/expired/offline states and role entry paths using existing Warm Utility components. Correct obsolete future-scope wording in design.md without changing approved visuals; include keyboard, back-navigation and 200-percent text checks.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- design.md [existing]
- docs/task-contracts/authorization-ux.md [planned]
- docs/task-results/AUTH-14.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no new brand, theme, fonts, screens or auth behavior.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
git diff --check -- design.md docs/task-contracts/authorization-ux.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Walk Owner, warehouse manager, rider, Store Owner and cashier entry states against the canonical contract.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-14.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="auth-90"></a>

### AUTH-90 — Auth integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, AUTH-08, AUTH-09, AUTH-10, AUTH-11, AUTH-12, AUTH-13, AUTH-14

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only AUTH-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only AUTH-90: Auth integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, AUTH-08, AUTH-09, AUTH-10, AUTH-11, AUTH-12, AUTH-13, AUTH-14. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/authorization.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all AUTH task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/AUTH-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/AUTH-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-tasks"></a>

## SETUP: Company, warehouse and store setup

<a id="setup-00"></a>

### SETUP-00 — Freeze company setup and commercial relationship contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** AUTH-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETUP-00 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-00: Freeze company setup and commercial relationship contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Specify company profile/warehouse/store relationship contracts, ownership-preserving active/deactivated states, customer enrollment confirmation and existing store approval compatibility. Define typed responses and required route/export wiring before feature workers start.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/company-store-setup.md [planned]
- docs/task-results/SETUP-00.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no stock changes, staff grant, automatic legacy adoption or live migration.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/company-store-setup.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace warehouse creation before rider invitation and independent-store enrollment without company membership.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-00.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-01"></a>

### SETUP-01 — Maintain company business details

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** AUTH-02, SETUP-00

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only SETUP-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-01: Maintain company business details.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: AUTH-02, SETUP-00. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner edits company name/contact details through scoped server validation and stable save IDs; managers see only operational context. Preserve identifiers and reject unauthorized ownership changes.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/company-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_functions.dart [planned]
- apps/admin/lib/features/company/company_profile_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/company.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/setup_01.test.ts [planned]
- docs/task-results/SETUP-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No staff grants, company deletion, ownership transfer or store retail profile edits.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/setup_01.test.ts
git diff --check -- firebase/functions/src/company/company-service.ts packages/sarisupply_firebase/lib/src/functions/company_functions.dart apps/admin/lib/features/company/company_profile_screen.dart packages/sarisupply_models/lib/src/company/company.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Edit company contact details, retry a save and verify rider/store-owner denial.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-02"></a>

### SETUP-02 — Create and maintain a company warehouse

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** SETUP-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only SETUP-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-02: Create and maintain a company warehouse.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: SETUP-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner creates/edits an active warehouse with address/contact and stable identity; invitation selection uses only authorized active warehouses. Deactivation must expose unresolved stock/work rather than orphan it.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/warehouse-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/warehouse_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_list_screen.dart [planned]
- packages/sarisupply_models/lib/src/inventory/warehouse.dart [existing]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/setup_02.test.ts [planned]
- docs/task-results/SETUP-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No stock movements, legacy merchant warehouse auto-adoption, manager creation or destructive warehouse deletion.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/setup_02.test.ts
git diff --check -- firebase/functions/src/company/warehouse-service.ts packages/sarisupply_firebase/lib/src/functions/warehouse_functions.dart apps/admin/lib/features/company/warehouse_list_screen.dart packages/sarisupply_models/lib/src/inventory/warehouse.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Create a warehouse, retry creation and verify unauthorized edit/deactivation with outstanding work is blocked.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-03"></a>

### SETUP-03 — Submit a store application

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** AUTH-04, SETUP-00

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETUP-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-03: Submit a store application.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: AUTH-04, SETUP-00. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store applicant edits and submits the existing business application, retains draft/rejection context and retries without duplicate tenancy. Submission establishes no company or approved store authority.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/merchant/application-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/merchant_application_functions.dart [existing]
- apps/pos/lib/features/owner_onboarding/presentation/merchant_application_screen.dart [existing]
- apps/admin/lib/features/merchant_review/presentation/merchant_review_detail_screen.dart [existing]
- docs/task-results/SETUP-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No approval, seeded retail stock, company ownership or bypass of pending status.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/merchant/application-service.ts packages/sarisupply_firebase/lib/src/functions/merchant_application_functions.dart apps/pos/lib/features/owner_onboarding/presentation/merchant_application_screen.dart apps/admin/lib/features/merchant_review/presentation/merchant_review_detail_screen.dart

Manual checks / observable acceptance:
Submit, retry after uncertain response, reject/resubmit and verify drafts survive navigation.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-04"></a>

### SETUP-04 — Approve or reject a store application

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** AUTH-03, SETUP-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only SETUP-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-04: Approve or reject a store application.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: AUTH-03, SETUP-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Platform Admin reviews application and records an explicit approval/rejection reason; approval creates exactly one independent-store business and owner/initial branch. Keep company relationship enrollment separate.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/merchant/application-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/merchant_application_functions.dart [existing]
- apps/pos/lib/features/owner_onboarding/presentation/merchant_application_screen.dart [existing]
- apps/admin/lib/features/merchant_review/presentation/merchant_review_detail_screen.dart [existing]
- firebase/functions/test/tasks/setup_04.test.ts [planned]
- docs/task-results/SETUP-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No automatic company membership, demonstration catalog injection or customer-store-to-company-branch conversion.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/setup_04.test.ts
git diff --check -- firebase/functions/src/merchant/application-service.ts packages/sarisupply_firebase/lib/src/functions/merchant_application_functions.dart apps/pos/lib/features/owner_onboarding/presentation/merchant_application_screen.dart apps/admin/lib/features/merchant_review/presentation/merchant_review_detail_screen.dart

Manual checks / observable acceptance:
Approve twice, reject with reason and confirm applicant cannot approve themselves.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-05"></a>

### SETUP-05 — Maintain store branches

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETUP-04, AUTH-07

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETUP-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-05: Maintain store branches.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: SETUP-04, AUTH-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner creates/edits/deactivates branches; managers edit only delegated operational details. Preserve all-branch membership semantics and prevent deactivation from hiding unresolved records.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/membership/membership-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/membership_functions.dart [existing]
- apps/pos/lib/features/management/presentation/management_screen.dart [existing]
- docs/task-results/SETUP-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No independent store ownership changes, warehouse conversion, cashier PIN changes or branch deletion.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/membership/membership-service.ts packages/sarisupply_firebase/lib/src/functions/membership_functions.dart apps/pos/lib/features/management/presentation/management_screen.dart

Manual checks / observable acceptance:
Create another branch and verify Owner versus scoped Manager controls and retained history.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-06"></a>

### SETUP-06 — Establish the company-to-store relationship

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETUP-01, SETUP-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETUP-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-06: Establish the company-to-store relationship.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETUP-01, SETUP-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company and Store Owner explicitly establish the commercial relationship using independent business IDs; show supplying-company identity in POS and customer-store identity in Admin. Server verifies both parties and prevents unauthorized binding.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/store-relationship-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/store_relationship_functions.dart [planned]
- apps/admin/lib/features/company/store_customers_screen.dart [planned]
- apps/pos/lib/features/management/presentation/supplying_company_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/store_relationship.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/setup_06.test.ts [planned]
- docs/task-results/SETUP-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No retail-data sharing consent, company membership for customers, automatic product mapping or order creation.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/setup_06.test.ts
git diff --check -- firebase/functions/src/company/store-relationship-service.ts packages/sarisupply_firebase/lib/src/functions/store_relationship_functions.dart apps/admin/lib/features/company/store_customers_screen.dart apps/pos/lib/features/management/presentation/supplying_company_screen.dart packages/sarisupply_models/lib/src/company/store_relationship.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Link one store, reject forged other-store confirmation and disconnect the relationship without deleting commercial history.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-07"></a>

### SETUP-07 — Activate a branch-scoped POS device

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETUP-05, AUTH-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETUP-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-07: Activate a branch-scoped POS device.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETUP-05, AUTH-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized store staff activate a device using existing human/device separation; backend derives immutable store/branch/device binding and the POS enters its actual cashier roster. Activation retries reuse the established device result.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/device/device-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/device_functions.dart [existing]
- apps/pos/lib/features/management/presentation/management_screen.dart [existing]
- apps/pos/lib/features/device_setup/presentation/device_setup_screen.dart [existing]
- firebase/functions/test/tasks/setup_07.test.ts [planned]
- docs/task-results/SETUP-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No company device authority, QR workflow invention if unsupported, rebinding occupied devices or clearing SQLite.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/setup_07.test.ts
git diff --check -- firebase/functions/src/device/device-service.ts packages/sarisupply_firebase/lib/src/functions/device_functions.dart apps/pos/lib/features/management/presentation/management_screen.dart apps/pos/lib/features/device_setup/presentation/device_setup_screen.dart

Manual checks / observable acceptance:
Activate one device and verify wrong branch, revoked branch, duplicate activation and cashier selection.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-08"></a>

### SETUP-08 — Manage device revocation and safe replacement

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETUP-07, AUTH-12

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETUP-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-08: Manage device revocation and safe replacement.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETUP-07, AUTH-12. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner revokes a device and provisions a replacement through existing trust controls, preserving old financial/audit records and distinguishing pending unsynced work. Never copy an active verifier/grant as a replacement device credential.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/device/device-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/device_functions.dart [existing]
- apps/pos/lib/features/management/presentation/management_screen.dart [existing]
- apps/pos/lib/features/device_setup/presentation/device_setup_screen.dart [existing]
- firebase/functions/test/tasks/setup_08.test.ts [planned]
- docs/task-results/SETUP-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No automatic backup overwrite, permanent record deletion or extending offline trust after denial.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/setup_08.test.ts
git diff --check -- firebase/functions/src/device/device-service.ts packages/sarisupply_firebase/lib/src/functions/device_functions.dart apps/pos/lib/features/management/presentation/management_screen.dart apps/pos/lib/features/device_setup/presentation/device_setup_screen.dart

Manual checks / observable acceptance:
Revoke old device, activate replacement and verify old device cannot refresh authorization.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="setup-90"></a>

### SETUP-90 — Setup integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** SETUP-01, SETUP-02, SETUP-03, SETUP-04, SETUP-05, SETUP-06, SETUP-07, SETUP-08, SETUP-00, AUTH-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETUP-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETUP-90: Setup integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETUP-01, SETUP-02, SETUP-03, SETUP-04, SETUP-05, SETUP-06, SETUP-07, SETUP-08, SETUP-00, AUTH-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-setup.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all SETUP task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/SETUP-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETUP-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-tasks"></a>

## CATALOG: Catalog and opening stock

<a id="catalog-01"></a>

### CATALOG-01 — Freeze company/store catalog and stock contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** AUTH-01, SETUP-06, SETUP-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only CATALOG-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-01: Freeze company/store catalog and stock contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-01, SETUP-06, SETUP-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define separate company selling products and store retail products, base units/factors, product mapping, immutable price snapshots, branch/warehouse ledger ownership and additive migration contracts. Record bounded sync and legacy-operation treatment.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/catalog-stock.md [planned]
- docs/task-results/CATALOG-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no namespace renames, destructive migrations or inferred ID equivalence.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/catalog-stock.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace one piece/pack product through company order, store receiving and retail sale with explicit conversions.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-02"></a>

### CATALOG-02 — Create and edit a store retail product

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** CATALOG-01, SETUP-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only CATALOG-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-02: Create and edit a store retail product.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: CATALOG-01, SETUP-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner manages name/SKU/category/base unit and base retail price with revision-safe save; local projection and server catalog agree. Reuse existing product form and reject cross-store updates.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/catalog/catalog-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- packages/sarisupply_models/lib/src/inventory/catalog.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- apps/pos/lib/features/catalog/catalog_screen.dart [existing]
- apps/pos/lib/features/catalog/product_dialog.dart [existing]
- firebase/functions/test/tasks/catalog_02.test.ts [planned]
- docs/task-results/CATALOG-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No company catalog writes, stock count changes, new photo provider or historical receipt repricing.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/catalog_02.test.ts
git diff --check -- firebase/functions/src/catalog/catalog-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart packages/sarisupply_models/lib/src/inventory/catalog.dart packages/sarisupply_inventory/lib/src/inventory_store.dart apps/pos/lib/features/catalog/catalog_screen.dart apps/pos/lib/features/catalog/product_dialog.dart

Manual checks / observable acceptance:
Save a product, retry, handle a stale revision and verify unauthorized cashier mutation is denied.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-03"></a>

### CATALOG-03 — Configure retail sale units and barcodes

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** CATALOG-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only CATALOG-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-03: Configure retail sale units and barcodes.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: CATALOG-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Owner assigns integer base-unit factors, unit prices and unique barcode mappings; exact matches return the matched unit/price and ambiguous barcodes require correction. Archive and sync preserve factors.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/catalog/catalog-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- packages/sarisupply_models/lib/src/inventory/catalog.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- apps/pos/lib/features/catalog/catalog_screen.dart [existing]
- apps/pos/lib/features/catalog/product_dialog.dart [existing]
- firebase/functions/test/tasks/catalog_03.test.ts [planned]
- docs/task-results/CATALOG-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No fractional stock model, silent unit changes on existing receipts or company mapping assumptions.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/catalog_03.test.ts
git diff --check -- firebase/functions/src/catalog/catalog-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart packages/sarisupply_models/lib/src/inventory/catalog.dart packages/sarisupply_inventory/lib/src/inventory_store.dart apps/pos/lib/features/catalog/catalog_screen.dart apps/pos/lib/features/catalog/product_dialog.dart

Manual checks / observable acceptance:
Scan piece and pack barcodes; verify quantity conversion, duplicate barcode rejection and exact price.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-04"></a>

### CATALOG-04 — Maintain the company wholesale catalog

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** CATALOG-01, SETUP-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only CATALOG-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-04: Maintain the company wholesale catalog.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: CATALOG-01, SETUP-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner manages sellable products/units and wholesale prices; operations sees scoped availability and orders retain accepted snapshots. Store users receive only the offered catalog, not upstream costs.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/catalog-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_catalog_functions.dart [planned]
- packages/sarisupply_models/lib/src/company/catalog.dart [planned]
- apps/admin/lib/features/company/company_catalog_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/catalog_04.test.ts [planned]
- docs/task-results/CATALOG-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No retail pricing control, order acceptance, inventory movement or product ID auto-linking.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/catalog_04.test.ts
git diff --check -- firebase/functions/src/company/catalog-service.ts packages/sarisupply_firebase/lib/src/functions/company_catalog_functions.dart packages/sarisupply_models/lib/src/company/catalog.dart apps/admin/lib/features/company/company_catalog_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Add a wholesale product and verify store-visible price versus hidden company cost fields.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-05"></a>

### CATALOG-05 — Map a company product to a store product

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** CATALOG-03, CATALOG-04, SETUP-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only CATALOG-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-05: Map a company product to a store product.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: CATALOG-03, CATALOG-04, SETUP-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner explicitly maps company product/unit to retail product/base units; server validates both businesses and positive conversion factors. Changes affect future orders only and incompatible mappings are blocked.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/product-mapping-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/product_mapping_functions.dart [planned]
- packages/sarisupply_models/lib/src/company/product_mapping.dart [planned]
- apps/pos/lib/features/catalog/company_product_mapping_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- firebase/functions/test/tasks/catalog_05.test.ts [planned]
- docs/task-results/CATALOG-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No name-based automatic links, historical manifest mutation or sharing store customer data.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/catalog_05.test.ts
git diff --check -- firebase/functions/src/company/product-mapping-service.ts packages/sarisupply_firebase/lib/src/functions/product_mapping_functions.dart packages/sarisupply_models/lib/src/company/product_mapping.dart apps/pos/lib/features/catalog/company_product_mapping_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Map a pack to pieces, reject incompatible units and verify another store cannot change the mapping.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-06"></a>

### CATALOG-06 — Capture, replace and remove a retail product photo

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** CATALOG-02

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only CATALOG-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-06: Capture, replace and remove a retail product photo.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: CATALOG-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Preserve the approved signed Cloudinary draft/save contract, camera/gallery recovery and cached offline viewing; replace/remove only through verified owner-scoped product save. Keep operation IDs across uncertain retries.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/media/product-image-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/product_image_functions.dart [existing]
- apps/pos/lib/features/catalog/product_dialog.dart [existing]
- apps/pos/lib/features/catalog/product_photo_format.dart [existing]
- packages/sarisupply_design_system/lib/src/product_photo_cache.dart [existing]
- docs/task-results/CATALOG-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No new provider, unsigned upload, paid add-on, offline upload queue, private media or delivery photos.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_design_system && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/media/product-image-service.ts packages/sarisupply_firebase/lib/src/functions/product_image_functions.dart apps/pos/lib/features/catalog/product_dialog.dart apps/pos/lib/features/catalog/product_photo_format.dart packages/sarisupply_design_system/lib/src/product_photo_cache.dart

Manual checks / observable acceptance:
Select a photo, retry upload/save, cancel the draft, remove the saved image and view offline.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-07"></a>

### CATALOG-07 — Search and browse branch stock

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** CATALOG-03

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only CATALOG-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-07: Search and browse branch stock.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: CATALOG-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Show branch-scoped products, base stock and expandable units with retained query/category state; exact barcode search uses the existing canonical catalog. Clearly distinguish empty/no-match/offline cache.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- apps/pos/lib/features/catalog/catalog_screen.dart [existing]
- apps/pos/lib/features/catalog/catalog_branch_screen.dart [existing]
- docs/task-results/CATALOG-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No sale commit, new sync protocol, shared price policy edits or pretend cross-device totals.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
git diff --check -- packages/sarisupply_inventory/lib/src/inventory_store.dart apps/pos/lib/features/catalog/catalog_screen.dart apps/pos/lib/features/catalog/catalog_branch_screen.dart

Manual checks / observable acceptance:
Search by name/SKU/barcode at phone width; switch branch and verify no stale results leak.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-08"></a>

### CATALOG-08 — Record opening stock once

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** CATALOG-02, SETUP-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only CATALOG-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-08: Record opening stock once.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: CATALOG-02, SETUP-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized store staff record opening quantities with a stable operation ID and atomic local ledger/outbox commit; server accepts/replays once. Show saved locally versus accepted and preserve pending work.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/catalog/catalog-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- apps/pos/lib/features/catalog/catalog_screen.dart [existing]
- firebase/functions/test/tasks/catalog_08.test.ts [planned]
- docs/task-results/CATALOG-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No absolute overwrite of later sales, warehouse stock creation or client-provided trusted actor scope.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/catalog_08.test.ts
git diff --check -- firebase/functions/src/catalog/catalog-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart packages/sarisupply_inventory/lib/src/inventory_store.dart apps/pos/lib/features/catalog/catalog_screen.dart

Manual checks / observable acceptance:
Record opening stock, replay upload and confirm a concurrent sale is not erased.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-09"></a>

### CATALOG-09 — Reconcile inventory deltas on reconnect

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** CATALOG-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only CATALOG-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-09: Reconcile inventory deltas on reconnect.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: CATALOG-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Reuse bounded inventory feeds and operation-specific push; persist cursors after durable projection, retain uncertain/conflicting legacy operations and reconcile negative stock explicitly.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- packages/sarisupply_inventory/lib/src/inventory_sync.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/catalog/catalog-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- apps/pos/lib/features/catalog/catalog_screen.dart [existing]
- firebase/functions/test/tasks/catalog_09.test.ts [planned]
- docs/task-results/CATALOG-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No count-only upload routing, dropping failed operations, unbounded full downloads or silent duplicate movement.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/catalog_09.test.ts
git diff --check -- packages/sarisupply_inventory/lib/src/inventory_sync.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/catalog/catalog-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart apps/pos/lib/features/catalog/catalog_screen.dart

Manual checks / observable acceptance:
Disconnect, count/sell locally, reconnect twice and inspect accepted, pending and conflict states.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="catalog-90"></a>

### CATALOG-90 — Catalog integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** CATALOG-01, CATALOG-02, CATALOG-03, CATALOG-04, CATALOG-05, CATALOG-06, CATALOG-07, CATALOG-08, CATALOG-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only CATALOG-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only CATALOG-90: Catalog integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: CATALOG-01, CATALOG-02, CATALOG-03, CATALOG-04, CATALOG-05, CATALOG-06, CATALOG-07, CATALOG-08, CATALOG-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/catalog-stock.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all CATALOG task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/CATALOG-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/CATALOG-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-tasks"></a>

## POS: Retail checkout

<a id="pos-01"></a>

### POS-01 — Freeze the cashier checkout contract

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** AUTH-09, CATALOG-09, SETUP-07, CATALOG-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-01: Freeze the cashier checkout contract.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-09, CATALOG-09, SETUP-07, CATALOG-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Confirm checkout scope, existing cashier grants, immutable intents, local atomicity, price/unit snapshots and ordered bounded sync. Document interrupted tender recovery and cash/manual QR UX without changing approved business policies.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/pos-checkout.md [planned]
- docs/task-results/POS-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no new tender providers, broader grants or reimplementation of verified persistence.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/pos-checkout.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace shift opening, sale, process death, duplicate upload, refund and shift close against existing code.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-02"></a>

### POS-02 — Open a cashier shift with float

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-02: Open a cashier shift with float.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Cashier starts one scoped device shift with integer-centavo opening float, stable event ID and durable sync; duplicate retries return the same shift and another actor cannot take it over.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/shift_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- firebase/functions/test/tasks/pos_02.test.ts [planned]
- docs/task-results/POS-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No automatic opening on login, cash sale, shift deletion or sharing another cashier grant.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/pos_02.test.ts
git diff --check -- apps/pos/lib/features/checkout/shift_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart firebase/functions/src/checkout/checkout-service.ts

Manual checks / observable acceptance:
Open offline, restart, retry and verify second open is refused while float appears once.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-03"></a>

### POS-03 — Build and resume a cart from search

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-02, CATALOG-07

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-03: Build and resume a cart from search.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: POS-02, CATALOG-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Cashier searches products, adds/removes lines and changes permitted units/quantities with existing price math; save a scoped draft and restore it after restart. Clear actions must respect frozen payment attempts.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/checkout_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/cart.dart [existing]
- docs/task-results/POS-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No tender submission, price override policy changes, shared catalog mutations or edits to committed sales.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
git diff --check -- apps/pos/lib/features/checkout/checkout_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/cart.dart

Manual checks / observable acceptance:
Add two units of one SKU, save/reopen the cart and verify scope plus totals without modifying finance code.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-04"></a>

### POS-04 — Scan a product with the rear camera

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** POS-03, CATALOG-03

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only POS-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-04: Scan a product with the rear camera.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: POS-03, CATALOG-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Use the existing rear-camera scanner to add the exact matched sale unit once per deliberate scan; permission denial, app pause and no-match provide manual search recovery. Preserve cart and release camera resources.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/barcode_scanner_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- docs/task-results/POS-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No new scanner dependency, front-camera flow, inventory mutation or financial-policy changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
git diff --check -- apps/pos/lib/features/checkout/barcode_scanner_screen.dart apps/pos/lib/features/checkout/checkout_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart

Manual checks / observable acceptance:
Scan twice deliberately, suppress repeated frames, deny camera access and resume after backgrounding.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-05"></a>

### POS-05 — Complete a cash sale with exact change

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-05: Complete a cash sale with exact change.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Validate tender and change using integer centavos; commit sale, tender, stock, draft completion and outbox atomically under the current cashier grant. Interrupted acknowledgement cannot create a second sale.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/payment_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/payment.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- firebase/functions/test/tasks/pos_05.test.ts [planned]
- docs/task-results/POS-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No float arithmetic, receipt deletion, silent repricing, payment gateway or alternative PIN trust.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/pos_05.test.ts
git diff --check -- apps/pos/lib/features/checkout/payment_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/payment.dart firebase/functions/src/checkout/checkout-service.ts

Manual checks / observable acceptance:
Pay exact/over/insufficient cash; inject a commit failure and retry after restart with one sale ID.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-06"></a>

### POS-06 — Record a manually confirmed QR sale

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-06: Record a manually confirmed QR sale.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Cashier records existing wallet/bank confirmation and reference before the same atomic sale path; retry keeps the payment attempt and explicitly states manual confirmation.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/payment_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/payment.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- firebase/functions/test/tasks/pos_06.test.ts [planned]
- docs/task-results/POS-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No provider-verified claim, payment API integration, automated bank access or fake receipt success.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/pos_06.test.ts
git diff --check -- apps/pos/lib/features/checkout/payment_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/payment.dart firebase/functions/src/checkout/checkout-service.ts

Manual checks / observable acceptance:
Confirm QR, cancel before commit and recover an uncertain commit; reference and tender remain correct.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-07"></a>

### POS-07 — Show and recover an immutable receipt

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-05, POS-06

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-07: Show and recover an immutable receipt.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: POS-05, POS-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Show committed receipt snapshots and branch/device sync status; recover presentation after process death without charging again. Receipt history uses scoped accepted/local records and truthful empty states.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/receipt_screen.dart [existing]
- apps/pos/lib/features/checkout/receipt_history_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- docs/task-results/POS-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No new money formulas, historical price edits, printing success claim or sale replay to recover UI.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
git diff --check -- apps/pos/lib/features/checkout/receipt_screen.dart apps/pos/lib/features/checkout/receipt_history_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart

Manual checks / observable acceptance:
Restart after sale commit before receipt display; reopen history and verify unit/price/tender snapshots.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-08"></a>

### POS-08 — Record cashier cash-in or cash-out

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-08: Record cashier cash-in or cash-out.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized active cashier records reasoned non-sale cash movement with sign-correct centavos and immutable journal/outbox entry; replay changes balance once and closed/wrong shift rejects it.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/shift_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- firebase/functions/test/tasks/pos_08.test.ts [planned]
- docs/task-results/POS-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No sale adjustment, opening float rewrite, company collections or direct balance overwrite.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/pos_08.test.ts
git diff --check -- apps/pos/lib/features/checkout/shift_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart firebase/functions/src/checkout/checkout-service.ts

Manual checks / observable acceptance:
Record cash-in/out, retry sync and confirm expected drawer movement and wrong-shift denial.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-09"></a>

### POS-09 — Close a shift and record discrepancy

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-05, POS-06, POS-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-09: Close a shift and record discrepancy.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-05, POS-06, POS-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Compute existing expected cash by tender and compensating entries; cashier records counted amount/discrepancy and closes once only after dependent local intents are accounted for. Keep pending acceptance visible.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/shift_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- firebase/functions/test/tasks/pos_09.test.ts [planned]
- docs/task-results/POS-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No silently discarded pending sales, retail-tax assumptions, retrospective journal edits or fake Z-reading certification.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/pos_09.test.ts
git diff --check -- apps/pos/lib/features/checkout/shift_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart firebase/functions/src/checkout/checkout-service.ts

Manual checks / observable acceptance:
Close with matching/mismatched counted cash, retry and verify a blocked prior event remains visible.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-10"></a>

### POS-10 — Lock checkout without losing business work

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-07, AUTH-09

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-10 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-10: Lock checkout without losing business work.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: POS-07, AUTH-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Lock disposes checkout and returns to named cashier selection; preserve scoped drafts, open-shift facts and pending operations. A new cashier cannot edit another actor's frozen payment attempt.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/checkout_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/cart.dart [existing]
- docs/task-results/POS-10.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No global database clearing, automatic shift transfer, extending expired grants or new backend policy.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
git diff --check -- apps/pos/lib/features/checkout/checkout_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/cart.dart

Manual checks / observable acceptance:
Lock with an open cart, sign in as another cashier and restore only that actor's authorized work.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-10.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-11"></a>

### POS-11 — Synchronize checkout with bounded replay

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-07, POS-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-11 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-11: Synchronize checkout with bounded replay.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-07, POS-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Push ordered immutable intents with existing stable IDs; server returns accepted/duplicate/conflict/blocked outcomes. Persist acknowledgements/cursors atomically and retain uncertain events and their required old grants securely.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- packages/sarisupply_inventory/lib/src/checkout_sync.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/checkout_functions.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- firebase/functions/test/tasks/pos_11.test.ts [planned]
- docs/task-results/POS-11.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unbounded feed, skipping earlier blocked finance, deleting pending events or granting credit locally.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/pos_11.test.ts
git diff --check -- packages/sarisupply_inventory/lib/src/checkout_sync.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_firebase/lib/src/functions/checkout_functions.dart firebase/functions/src/checkout/checkout-service.ts apps/pos/lib/features/checkout/checkout_controller.dart

Manual checks / observable acceptance:
Simulate outage and partial acknowledgement; repeat sync and inspect stock/tender/shift effects once.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-11.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="pos-90"></a>

### POS-90 — Pos integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** POS-01, POS-02, POS-03, POS-04, POS-05, POS-06, POS-07, POS-08, POS-09, POS-10, POS-11

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only POS-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only POS-90: Pos integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-01, POS-02, POS-03, POS-04, POS-05, POS-06, POS-07, POS-08, POS-09, POS-10, POS-11. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/pos-checkout.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all POS task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/POS-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/POS-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-tasks"></a>

## RETAIL: Retail stock, reversals and customer credit

<a id="retail-01"></a>

### RETAIL-01 — Freeze retail adjustment and credit contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** POS-11, POS-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-01: Freeze retail adjustment and credit contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-11, POS-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Fix count versus delta semantics, batch/transfer ownership, refund approval binding, promotion rounding and customer/device credit reservations. Identify reusable code and record compensating-event/retry contracts.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/retail-operations.md [planned]
- docs/task-results/RETAIL-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no new credit underwriting, shared company/store ledger or automatic VAT policy.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/retail-operations.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace negative stock, refund after repayment, partial transfer receipt and expired credit reservation.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-02"></a>

### RETAIL-02 — Record a physical stock count

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-02: Record a physical stock count.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized store staff count a product using current base stock context and stable intent; local commit queues once and server handles stale/concurrent context explicitly. Explain count versus adjustment.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/adjustment_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/catalog/catalog-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- firebase/functions/test/tasks/retail_02.test.ts [planned]
- docs/task-results/RETAIL-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No warehouse count, resetting all branch quantities or overwriting concurrent sales silently.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_02.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/adjustment_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/catalog/catalog-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart

Manual checks / observable acceptance:
Count zero/positive quantities, simulate concurrent sale and retry with explicit conflict handling.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-03"></a>

### RETAIL-03 — Record a reasoned retail stock adjustment

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-03: Record a reasoned retail stock adjustment.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized staff apply positive/negative base-unit delta with reason and atomic ledger/outbox commit; pending status remains recoverable and server derives scope.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/adjustment_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/catalog/catalog-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- firebase/functions/test/tasks/retail_03.test.ts [planned]
- docs/task-results/RETAIL-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No destructive edit of prior ledger rows, anonymous correction, warehouse movement or hidden negative balance.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_03.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/adjustment_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/catalog/catalog-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart

Manual checks / observable acceptance:
Record damage/correction, reject zero/invalid delta and verify replay creates one movement.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-04"></a>

### RETAIL-04 — Receive external retail stock into a branch

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-01, CATALOG-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-04: Receive external retail stock into a branch.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-01, CATALOG-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized store staff record actual goods from an external purchase with explicit source, units and stable receiving ID; commit local movement and upload once. Label this separately from company-order receipt.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/receiving_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/catalog/receiving-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- firebase/functions/test/tasks/retail_04.test.ts [planned]
- docs/task-results/RETAIL-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No bypass of ordered company delivery receiving, automatic company stock debit or duplicate retail receipt.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_04.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/receiving_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/catalog/receiving-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart

Manual checks / observable acceptance:
Receive a pack into base units, partially acknowledge sync and retry without increasing stock twice.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-05"></a>

### RETAIL-05 — Track batches and expiry at receiving

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** RETAIL-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RETAIL-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-05: Track batches and expiry at receiving.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RETAIL-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Capture batch and valid expiry together, retain them through receiving/stock views, and distinguish available, expired and unknown-date stock. Preserve base-unit quantities and source provenance.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/batch_expiry_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- packages/sarisupply_models/lib/src/inventory/batch_expiry.dart [existing]
- firebase/functions/src/catalog/receiving-service.ts [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- firebase/functions/test/tasks/retail_05.test.ts [planned]
- docs/task-results/RETAIL-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No automatic financial write-off, invented expiry, unsupported FEFO allocation rewrite or product deletion.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_05.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/batch_expiry_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart packages/sarisupply_models/lib/src/inventory/batch_expiry.dart firebase/functions/src/catalog/receiving-service.ts apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Receive two batches, reject malformed dates and inspect expiring/expired labels at 200-percent text.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-06"></a>

### RETAIL-06 — Dispatch a same-store branch transfer

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-01, SETUP-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-06: Dispatch a same-store branch transfer.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-01, SETUP-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized source staff dispatch an explicit same-business transfer with destination branch and stable operation ID; goods leave source availability once and remain in transit.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/transfer_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/catalog/transfer-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- firebase/functions/test/tasks/retail_06.test.ts [planned]
- docs/task-results/RETAIL-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No independent-store sales disguised as transfer, auto-receipt or cross-business branch permission.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_06.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/transfer_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/catalog/transfer-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart

Manual checks / observable acceptance:
Dispatch one transfer, retry and verify unrelated merchant/destination denial.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-07"></a>

### RETAIL-07 — Receive a branch transfer partially or fully

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-07: Receive a branch transfer partially or fully.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized destination staff confirm actual quantities with retry-safe receiving; update destination once and retain unresolved in-transit quantities/discrepancies. Discover transfers using bounded scoped feeds.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/transfer_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/catalog/transfer-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart [existing]
- firebase/functions/test/tasks/retail_07.test.ts [planned]
- docs/task-results/RETAIL-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No source actor self-receipt for unauthorized branch, silent quantity inflation or deleting discrepancies.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_07.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/transfer_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/catalog/transfer-service.ts packages/sarisupply_firebase/lib/src/functions/inventory_functions.dart

Manual checks / observable acceptance:
Receive partially, reconnect twice and complete the remainder with correct source/destination totals.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-08"></a>

### RETAIL-08 — Configure and apply a scoped promotion

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-01, POS-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-08: Configure and apply a scoped promotion.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-01, POS-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner manages the approved promotion policy; cashier applies eligible discounts with existing centavo rounding and immutable receipt snapshots. Validate overlap/eligibility and display savings clearly.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/promotion_screen.dart [planned]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/promotion.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- firebase/functions/test/tasks/retail_08.test.ts [planned]
- docs/task-results/RETAIL-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No arbitrary cashier price overrides, wholesale promotions, changing old receipts or invented discount stacking.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_08.test.ts
git diff --check -- apps/pos/lib/features/checkout/promotion_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/promotion.dart firebase/functions/src/checkout/checkout-service.ts apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Apply eligible/ineligible promotion, change quantity/unit and verify exact totals before and after replay.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-09"></a>

### RETAIL-09 — Refund exact receipt lines with Owner approval

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-01, POS-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-09: Refund exact receipt lines with Owner approval.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-01, POS-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Bind approved reversal to the exact original receipt, unit, price, quantities, reason and tender; prevent cumulative over-refund. Create compensating local/server finance and stock events once.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/refund_screen.dart [existing]
- apps/pos/lib/features/checkout/owner_reversal_approval.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/refund.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- firebase/functions/test/tasks/retail_09.test.ts [planned]
- docs/task-results/RETAIL-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No current-price refunds, changing original receipt, recycled approval for another intent or allowance replenishment.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_09.test.ts
git diff --check -- apps/pos/lib/features/checkout/refund_screen.dart apps/pos/lib/features/checkout/owner_reversal_approval.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/refund.dart firebase/functions/src/checkout/checkout-service.ts

Manual checks / observable acceptance:
Partial refund, duplicate retry, different payload with same ID and unrelated Owner approval must behave correctly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-10"></a>

### RETAIL-10 — Void an eligible sale with exact approval

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-10 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-10: Void an eligible sale with exact approval.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized Owner approves the exact full-void intent under existing policy; record immutable compensation by original tender and correct stock quantities. Already-refunded/ineligible amounts need explicit review.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/refund_screen.dart [existing]
- apps/pos/lib/features/checkout/owner_reversal_approval.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/refund.dart [existing]
- firebase/functions/src/checkout/checkout-service.ts [existing]
- firebase/functions/test/tasks/retail_10.test.ts [planned]
- docs/task-results/RETAIL-10.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No deleting sale, silent tender conversion, repeated compensation or cashier-only approval.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_10.test.ts
git diff --check -- apps/pos/lib/features/checkout/refund_screen.dart apps/pos/lib/features/checkout/owner_reversal_approval.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/refund.dart firebase/functions/src/checkout/checkout-service.ts

Manual checks / observable acceptance:
Void once, replay, try an altered intent and verify original receipt remains auditable.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-10.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-11"></a>

### RETAIL-11 — Manage a retail customer credit account

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** RETAIL-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RETAIL-11 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-11: Manage a retail customer credit account.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RETAIL-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner manages scoped customer identity/contact and approved credit limits; backend returns only authorized account data and names resolve in POS. Avoid fabricated balances or copied company customer identities.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/customer_credit_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/checkout/customer-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/customer_functions.dart [existing]
- firebase/functions/test/tasks/retail_11.test.ts [planned]
- docs/task-results/RETAIL-11.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No local credit grants, company trade-credit facility, negative-limit reset or exposing another store's customers.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_11.test.ts
git diff --check -- apps/pos/lib/features/checkout/customer_credit_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/checkout/customer-service.ts packages/sarisupply_firebase/lib/src/functions/customer_functions.dart

Manual checks / observable acceptance:
Create/edit one customer, retry creation and verify branch/device access and readable outstanding-balance states.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-11.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-12"></a>

### RETAIL-12 — Reserve and consume offline customer allowance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-11, POS-11

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-12 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-12: Reserve and consume offline customer allowance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-11, POS-11. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Server reserves customer/device allowance; checkout durably consumes it with stable payment attempt and immutable credit sale. Expiry or offline repayment never refreshes spent allowance; unusable drafts retain explicit recovery.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/customer_credit_screen.dart [existing]
- apps/pos/lib/features/checkout/payment_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- firebase/functions/src/checkout/customer-service.ts [existing]
- packages/sarisupply_models/lib/src/checkout/customer_credit.dart [existing]
- firebase/functions/test/tasks/retail_12.test.ts [planned]
- docs/task-results/RETAIL-12.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No client-minted allowance, global unsecured credit balance, shared reservation across devices or hidden cancellation.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_12.test.ts
git diff --check -- apps/pos/lib/features/checkout/customer_credit_screen.dart apps/pos/lib/features/checkout/payment_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart firebase/functions/src/checkout/customer-service.ts packages/sarisupply_models/lib/src/checkout/customer_credit.dart

Manual checks / observable acceptance:
Reserve, disconnect, charge, expire and reconnect; two devices cannot exceed reserved allowance.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-12.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-13"></a>

### RETAIL-13 — Record and synchronize a customer repayment

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-12

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-13 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-13: Record and synchronize a customer repayment.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-12. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Cashier records authorized repayment with tender/reference and ordinal-bearing journal/outbox commit; backend accepts once and adjusts debt correctly. Repayment shows pending versus accepted and does not replenish allowance offline.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/checkout/customer_credit_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- firebase/functions/src/checkout/customer-service.ts [existing]
- packages/sarisupply_firebase/lib/src/functions/customer_functions.dart [existing]
- apps/pos/lib/features/checkout/payment_screen.dart [existing]
- apps/pos/lib/features/checkout/checkout_controller.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_models/lib/src/checkout/customer_credit.dart [existing]
- firebase/functions/test/tasks/retail_13.test.ts [planned]
- docs/task-results/RETAIL-13.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No editing historical balance, negative debt, offline allowance reuse or merging rider cash into retail debt.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/retail_13.test.ts
git diff --check -- apps/pos/lib/features/checkout/customer_credit_screen.dart packages/sarisupply_inventory/lib/src/inventory_store.dart firebase/functions/src/checkout/customer-service.ts packages/sarisupply_firebase/lib/src/functions/customer_functions.dart apps/pos/lib/features/checkout/payment_screen.dart apps/pos/lib/features/checkout/checkout_controller.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_models/lib/src/checkout/customer_credit.dart

Manual checks / observable acceptance:
Repay partially, retry upload and refund an already-repaid credit sale through explicit review.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-13.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="retail-90"></a>

### RETAIL-90 — Retail integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** RETAIL-01, RETAIL-02, RETAIL-03, RETAIL-04, RETAIL-05, RETAIL-06, RETAIL-07, RETAIL-08, RETAIL-09, RETAIL-10, RETAIL-11, RETAIL-12, RETAIL-13

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RETAIL-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RETAIL-90: Retail integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RETAIL-01, RETAIL-02, RETAIL-03, RETAIL-04, RETAIL-05, RETAIL-06, RETAIL-07, RETAIL-08, RETAIL-09, RETAIL-10, RETAIL-11, RETAIL-12, RETAIL-13. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/retail-operations.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all RETAIL task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/RETAIL-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RETAIL-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-tasks"></a>

## PURCHASING: Company supplier purchasing and warehouse stock

<a id="purchasing-01"></a>

### PURCHASING-01 — Freeze company purchasing contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** AUTH-01, SETUP-02, CATALOG-04, CATALOG-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only PURCHASING-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-01: Freeze company purchasing contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: AUTH-01, SETUP-02, CATALOG-04, CATALOG-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define company-owned suppliers/POs, line cost/unit snapshots, actual receiving, batch provenance, warehouse scope and stable receiving operations. Fix additive local company cache/outbox ownership; retain legacy merchant POs for migration review.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/company-purchasing.md [planned]
- docs/task-results/PURCHASING-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no automatic adoption of store POs, cost disclosure to customers or billing change.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/company-purchasing.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace one supplier pack purchase into company warehouse base stock and expose uncertain receiving retries.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-02"></a>

### PURCHASING-02 — Manage the upstream supplier directory

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** PURCHASING-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only PURCHASING-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-02: Manage the upstream supplier directory.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: PURCHASING-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-purchasing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner manages supplier contacts/status with retry-safe saves; warehouse operations gets only required operational details. A directory row is not an authenticated staff or store account.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/supplier-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_supplier_functions.dart [planned]
- packages/sarisupply_models/lib/src/inventory/supplier.dart [existing]
- apps/admin/lib/features/company/company_suppliers_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/purchasing_02.test.ts [planned]
- docs/task-results/PURCHASING-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No purchase order, store tenant mutation, supplier login, new schema migrations or shared registry edits.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/purchasing_02.test.ts
git diff --check -- firebase/functions/src/company/supplier-service.ts packages/sarisupply_firebase/lib/src/functions/company_supplier_functions.dart packages/sarisupply_models/lib/src/inventory/supplier.dart apps/admin/lib/features/company/company_suppliers_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Add/edit/deactivate a supplier and verify duplicate-save recovery plus unrelated-user denial.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-03"></a>

### PURCHASING-03 — Issue a company supplier purchase order

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** PURCHASING-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only PURCHASING-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-03: Issue a company supplier purchase order.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: PURCHASING-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-purchasing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner creates/submits a PO with verified active supplier, warehouse, product units and integer-centavo cost snapshots. Use immutable operation identity and explicit submitted state; managers cannot change ownership or agreed cost arbitrarily.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/purchase-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_purchase_functions.dart [planned]
- packages/sarisupply_models/lib/src/inventory/purchase_order.dart [existing]
- apps/admin/lib/features/company/company_purchase_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/company_purchase_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/purchasing_03.test.ts [planned]
- docs/task-results/PURCHASING-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No supplier payment processing, stock increase on submission, retail order creation or unlimited line payloads.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/purchasing_03.test.ts
git diff --check -- firebase/functions/src/company/purchase-service.ts packages/sarisupply_firebase/lib/src/functions/company_purchase_functions.dart packages/sarisupply_models/lib/src/inventory/purchase_order.dart apps/admin/lib/features/company/company_purchase_screen.dart packages/sarisupply_inventory/lib/src/company_purchase_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Submit, repeat an uncertain submission and reject stale supplier/unit data without duplicate PO.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-04"></a>

### PURCHASING-04 — Receive a supplier PO partially

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** PURCHASING-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only PURCHASING-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-04: Receive a supplier PO partially.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: PURCHASING-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-purchasing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Scoped operations records actual delivered quantities and optional valid batch/expiry; trusted transaction updates PO received quantities, company stock/cost provenance and receipt event once.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/warehouse-receiving-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/warehouse_receiving_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_receiving_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/company_purchase_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/purchasing_04.test.ts [planned]
- docs/task-results/PURCHASING-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No over-receiving without explicit approved policy, store stock mutation, PO deletion or price edits on old receipts.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/purchasing_04.test.ts
git diff --check -- firebase/functions/src/company/warehouse-receiving-service.ts packages/sarisupply_firebase/lib/src/functions/warehouse_receiving_functions.dart apps/admin/lib/features/company/warehouse_receiving_screen.dart packages/sarisupply_inventory/lib/src/company_purchase_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Receive part, retry its operation and receive remaining units; totals and cost stay correct.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-05"></a>

### PURCHASING-05 — Review company warehouse stock and costs

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** PURCHASING-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only PURCHASING-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-05: Review company warehouse stock and costs.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: PURCHASING-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-purchasing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Show physical/reserved/available/in-transit or quarantined quantities from canonical company records with scope/freshness; cost views are Company Owner-only except operational values explicitly required for receipts.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/warehouse-stock-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/warehouse_stock_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_stock_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/company_stock_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/purchasing_05.test.ts [planned]
- docs/task-results/PURCHASING-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No customer access to cost, local cache presented as complete, inventory valuation estimate called verified or fabricated missing costs.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/purchasing_05.test.ts
git diff --check -- firebase/functions/src/company/warehouse-stock-service.ts packages/sarisupply_firebase/lib/src/functions/warehouse_stock_functions.dart apps/admin/lib/features/company/warehouse_stock_screen.dart packages/sarisupply_inventory/lib/src/company_stock_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Compare two warehouse scopes, unknown costs and pending receipts; verify store/rider denial.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-06"></a>

### PURCHASING-06 — Correct company warehouse stock with a reason

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** PURCHASING-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only PURCHASING-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-06: Correct company warehouse stock with a reason.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: PURCHASING-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-purchasing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized company correction uses stable movement ID, reason and current reservation checks; never consumes reserved stock silently. Preserve audit and outbox evidence across uncertain retries.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/warehouse-stock-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/warehouse_stock_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_stock_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/company_stock_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/purchasing_06.test.ts [planned]
- docs/task-results/PURCHASING-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No retail branch adjustment, deleting prior movements, unauthorized manager scope or auto-restocking returns.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/purchasing_06.test.ts
git diff --check -- firebase/functions/src/company/warehouse-stock-service.ts packages/sarisupply_firebase/lib/src/functions/warehouse_stock_functions.dart apps/admin/lib/features/company/warehouse_stock_screen.dart packages/sarisupply_inventory/lib/src/company_stock_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Correct stock, attempt reduction below reservations and replay once with canonical totals unchanged on duplicate.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-07"></a>

### PURCHASING-07 — Recover a pending company purchase operation

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** PURCHASING-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only PURCHASING-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-07: Recover a pending company purchase operation.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: PURCHASING-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-purchasing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Persist bounded company purchasing outbox/cursors and reconnect under current human/warehouse authority; retain conflict/blocked/uncertain work with safe recovery. Repeated receiving does not duplicate physical stock or cost entries.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/purchase-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_purchase_functions.dart [planned]
- packages/sarisupply_models/lib/src/inventory/purchase_order.dart [existing]
- apps/admin/lib/features/company/company_purchase_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/company_purchase_store.dart [planned]
- firebase/functions/src/company/warehouse-receiving-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/warehouse_receiving_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_receiving_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/purchasing_07.test.ts [planned]
- docs/task-results/PURCHASING-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No offline privileged server acceptance, sharing POS cashier grants, discarding legacy PO queues or wholesale sync redesign.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/purchasing_07.test.ts
git diff --check -- firebase/functions/src/company/purchase-service.ts packages/sarisupply_firebase/lib/src/functions/company_purchase_functions.dart packages/sarisupply_models/lib/src/inventory/purchase_order.dart apps/admin/lib/features/company/company_purchase_screen.dart packages/sarisupply_inventory/lib/src/company_purchase_store.dart firebase/functions/src/company/warehouse-receiving-service.ts packages/sarisupply_firebase/lib/src/functions/warehouse_receiving_functions.dart apps/admin/lib/features/company/warehouse_receiving_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Interrupt a receipt request, restart Operations and retry; blocked warehouse assignment remains reviewable.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="purchasing-90"></a>

### PURCHASING-90 — Purchasing integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** PURCHASING-01, PURCHASING-02, PURCHASING-03, PURCHASING-04, PURCHASING-05, PURCHASING-06, PURCHASING-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only PURCHASING-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only PURCHASING-90: Purchasing integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: PURCHASING-01, PURCHASING-02, PURCHASING-03, PURCHASING-04, PURCHASING-05, PURCHASING-06, PURCHASING-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-purchasing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all PURCHASING task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/PURCHASING-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/PURCHASING-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-tasks"></a>

## ORDERS: Store-confirmed replenishment orders

<a id="orders-01"></a>

### ORDERS-01 — Freeze independent-store order contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** CATALOG-05, PURCHASING-05, SETUP-06, PURCHASING-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-01: Freeze independent-store order contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: CATALOG-05, PURCHASING-05, SETUP-06, PURCHASING-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define seller/buyer/branch identities, company/store product-unit mapping, wholesale price snapshots, draft/confirmation/acceptance/amendment/cancellation states and bounded feeds. Specify consent categories and revisions without exposing private retail records.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/company-store-orders.md [planned]
- docs/task-results/ORDERS-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no auto-orders, inferred mappings, store-as-company-branch model or trade credit beyond approved scope.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/company-store-orders.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace a store-confirmed order with changed price/shortage, unauthorized party, retry and cancellation.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-02"></a>

### ORDERS-02 — Control replenishment-summary sharing

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** ORDERS-01, AUTH-13

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-02: Control replenishment-summary sharing.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: ORDERS-01, AUTH-13. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner enables or revokes stock and/or sales summary consent per supplying company; trusted server checks current consent on reads. Default is off and clients discard observed revoked cached summaries.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/store-consent-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/store_consent_functions.dart [planned]
- apps/pos/lib/features/management/presentation/summary_sharing_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/store_consent.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- firebase/functions/test/tasks/orders_02.test.ts [planned]
- docs/task-results/ORDERS-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No raw receipts/customers, cashier consent, implicit sharing on order placement or erasing commercial history on revocation.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/orders_02.test.ts
git diff --check -- firebase/functions/src/company/store-consent-service.ts packages/sarisupply_firebase/lib/src/functions/store_consent_functions.dart apps/pos/lib/features/management/presentation/summary_sharing_screen.dart packages/sarisupply_models/lib/src/company/store_consent.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Enable only stock summaries, deny sales, revoke and verify later company reads/cache refresh are blocked.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-03"></a>

### ORDERS-03 — Draft suggested replenishment quantities

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** ORDERS-01, CATALOG-09

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-03: Draft suggested replenishment quantities.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: ORDERS-01, CATALOG-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner reviews local low-stock suggestions, explicit company mappings/units and editable purchase quantities; persist an identified draft and disclose stock freshness. Suggestions never commit purchases automatically.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/restock_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/store_order_store.dart [planned]
- packages/sarisupply_models/lib/src/company/store_order.dart [planned]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- docs/task-results/ORDERS-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No company acceptance, hardcoded fake availability, blanket retail sharing or automatic order submission.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
git diff --check -- apps/pos/lib/features/inventory/presentation/restock_screen.dart packages/sarisupply_inventory/lib/src/store_order_store.dart packages/sarisupply_models/lib/src/company/store_order.dart packages/sarisupply_models/lib/sarisupply_models.dart

Manual checks / observable acceptance:
Add shortages, edit quantities, restart draft and handle unmapped product without losing other lines.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-04"></a>

### ORDERS-04 — Confirm and submit a store purchase

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** ORDERS-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-04: Confirm and submit a store purchase.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: ORDERS-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner confirms company, destination branch, quantities and offered price snapshots; durable identified submission becomes accepted by server once or remains pending/needs reconfirmation. Check active relationship and buyer authority.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/restock_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/store_order_store.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart [planned]
- firebase/functions/src/company/store-order-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- firebase/functions/test/tasks/orders_04.test.ts [planned]
- docs/task-results/ORDERS-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No cashier purchase approval, company staff submitting for store, offline warehouse reservation or duplicate orders.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/orders_04.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/restock_screen.dart packages/sarisupply_inventory/lib/src/store_order_store.dart packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart firebase/functions/src/company/store-order-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart

Manual checks / observable acceptance:
Confirm offline draft, submit online, retry uncertain response and reject forged buyer/branch.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-05"></a>

### ORDERS-05 — Accept or reject an order in Operations

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** ORDERS-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-05: Accept or reject an order in Operations.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: ORDERS-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Scoped Operations reviews actual store orders and accepts unchanged agreed lines or rejects with reason; current stock/warehouse/customer relationship checks run server-side. Changed commercial terms route to reconfirmation.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/store_order_queue_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/company_order_functions.dart [planned]
- firebase/functions/src/company/company-order-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/orders_05.test.ts [planned]
- docs/task-results/ORDERS-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No store data access beyond order, reservation implementation, silent substitutions or acceptance by rider.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/orders_05.test.ts
git diff --check -- apps/admin/lib/features/company/store_order_queue_screen.dart packages/sarisupply_firebase/lib/src/functions/company_order_functions.dart firebase/functions/src/company/company-order-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Accept one order, reject another, replay acceptance and verify other warehouse manager denial.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-06"></a>

### ORDERS-06 — Propose and reconfirm an order amendment

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** ORDERS-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-06: Propose and reconfirm an order amendment.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: ORDERS-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Operations proposes changed quantity/product/price with clear differences; Store Owner reconfirms the exact new revision before fulfillment. Previous accepted snapshots remain auditable and stale confirmation rejects.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/store_order_detail_screen.dart [planned]
- apps/pos/lib/features/inventory/presentation/store_order_detail_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/company_order_functions.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart [planned]
- firebase/functions/src/company/company-order-service.ts [planned]
- packages/sarisupply_inventory/lib/src/store_order_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/orders_06.test.ts [planned]
- docs/task-results/ORDERS-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unilateral repricing, automatic store consent, changing dispatched manifests or unrelated product substitution.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/orders_06.test.ts
git diff --check -- apps/admin/lib/features/company/store_order_detail_screen.dart apps/pos/lib/features/inventory/presentation/store_order_detail_screen.dart packages/sarisupply_firebase/lib/src/functions/company_order_functions.dart packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart firebase/functions/src/company/company-order-service.ts packages/sarisupply_inventory/lib/src/store_order_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Propose shortage/substitution, decline/reconfirm in POS and retry an obsolete revision.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-07"></a>

### ORDERS-07 — Cancel an eligible confirmed order

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** ORDERS-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-07: Cancel an eligible confirmed order.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: ORDERS-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized party requests allowed pre-dispatch cancellation under the frozen state contract; reject or explicitly resolve work already reserved/picked. Keep immutable reason and no duplicate compensation.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/store_order_detail_screen.dart [planned]
- apps/pos/lib/features/inventory/presentation/store_order_detail_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/company_order_functions.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart [planned]
- firebase/functions/src/company/company-order-service.ts [planned]
- packages/sarisupply_inventory/lib/src/store_order_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/orders_07.test.ts [planned]
- docs/task-results/ORDERS-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No cancelling delivered records, deleting finance/history, releasing future reservations without verified state or pretending rider work vanished.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/orders_07.test.ts
git diff --check -- apps/admin/lib/features/company/store_order_detail_screen.dart apps/pos/lib/features/inventory/presentation/store_order_detail_screen.dart packages/sarisupply_firebase/lib/src/functions/company_order_functions.dart packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart firebase/functions/src/company/company-order-service.ts packages/sarisupply_inventory/lib/src/store_order_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Cancel before fulfillment; verify dispatched cancellation is blocked and duplicate request is harmless.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-08"></a>

### ORDERS-08 — Track a store order and its delivery state

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** ORDERS-05, ORDERS-07

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only ORDERS-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-08: Track a store order and its delivery state.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: ORDERS-05, ORDERS-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Show store-authorized order timeline, agreed prices, pending amendments and eventual linked delivery facts using bounded cached reads; unknown or unsynced state is explicit. No company internal cost or other store orders.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/store_order_detail_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart [planned]
- packages/sarisupply_inventory/lib/src/store_order_store.dart [planned]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- docs/task-results/ORDERS-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No new mutation, rider selection, dispatch control, schema change or raw retail insights.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
git diff --check -- apps/pos/lib/features/inventory/presentation/store_order_detail_screen.dart packages/sarisupply_firebase/lib/src/functions/store_order_functions.dart packages/sarisupply_inventory/lib/src/store_order_store.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Track pending/accepted/rejected/cancelled orders and view cached timeline offline with freshness.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="orders-90"></a>

### ORDERS-90 — Orders integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** ORDERS-01, ORDERS-02, ORDERS-03, ORDERS-04, ORDERS-05, ORDERS-06, ORDERS-07, ORDERS-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only ORDERS-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only ORDERS-90: Orders integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: ORDERS-01, ORDERS-02, ORDERS-03, ORDERS-04, ORDERS-05, ORDERS-06, ORDERS-07, ORDERS-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-store-orders.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all ORDERS task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/ORDERS-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/ORDERS-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="fulfillment-tasks"></a>

## FULFILLMENT: Warehouse reservation, picking and packing

<a id="fulfillment-01"></a>

### FULFILLMENT-01 — Freeze warehouse fulfillment contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** ORDERS-06, PURCHASING-07, ORDERS-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only FULFILLMENT-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only FULFILLMENT-01: Freeze warehouse fulfillment contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: ORDERS-06, PURCHASING-07, ORDERS-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define accepted order revision, reservation owner, available stock, partial pick/pack, package identity, shipment handoff and release compensation. Specify exactly when stock becomes in transit and how canceled or changed work is reconciled.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/warehouse-fulfillment.md [planned]
- docs/task-results/FULFILLMENT-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no store stock increase, delivery-proof-as-receipt, silent order amendment or legacy manifest rewrite.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/warehouse-fulfillment.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace reservation, partial pick, canceled draft, dispatch and return into company and store ledgers separately.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/FULFILLMENT-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="fulfillment-02"></a>

### FULFILLMENT-02 — Reserve company stock for an accepted order

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** FULFILLMENT-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only FULFILLMENT-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only FULFILLMENT-02: Reserve company stock for an accepted order.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: FULFILLMENT-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/warehouse-fulfillment.md. Read design.md before changing UI/copy.

Goal and acceptance:
Scoped Operations reserves available stock transactionally for the reconfirmed order revision and warehouse; concurrent orders cannot over-reserve. Replay returns existing reservation and a failed request preserves the order for review.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/stock-reservation-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_fulfillment_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/company_stock_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/fulfillment_02.test.ts [planned]
- docs/task-results/FULFILLMENT-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No stock removal on reservation, retailer receiving, client-only availability checks or automatic supplier purchase.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/fulfillment_02.test.ts
git diff --check -- firebase/functions/src/company/stock-reservation-service.ts packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart apps/admin/lib/features/company/warehouse_fulfillment_screen.dart packages/sarisupply_inventory/lib/src/company_stock_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Reserve competing orders, repeat one request and confirm physical/reserved/available quantities.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/FULFILLMENT-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="fulfillment-03"></a>

### FULFILLMENT-03 — Pick accepted order quantities

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** FULFILLMENT-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only FULFILLMENT-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only FULFILLMENT-03: Pick accepted order quantities.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: FULFILLMENT-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/warehouse-fulfillment.md. Read design.md before changing UI/copy.

Goal and acceptance:
Operations records actual picked base-unit quantities against reservation and accepted order; identify shortages and retain remaining/released reservation according to the contract. Picking retries do not duplicate allocations.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/pick-pack-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_fulfillment_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/package_manifest.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/fulfillment_03.test.ts [planned]
- docs/task-results/FULFILLMENT-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No substitute product without reconfirmation, company-wide manager access, order cost edits or store receipt.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/fulfillment_03.test.ts
git diff --check -- firebase/functions/src/company/pick-pack-service.ts packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart apps/admin/lib/features/company/warehouse_fulfillment_screen.dart packages/sarisupply_models/lib/src/company/package_manifest.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Pick partially, report shortage, resume and reject quantity beyond allowed reservation.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/FULFILLMENT-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="fulfillment-04"></a>

### FULFILLMENT-04 — Pack identifiable order packages

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** FULFILLMENT-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only FULFILLMENT-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only FULFILLMENT-04: Pack identifiable order packages.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: FULFILLMENT-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/warehouse-fulfillment.md. Read design.md before changing UI/copy.

Goal and acceptance:
Operations packs actual picked goods into stable manifests with package/seal codes and accepted unit/price/destination snapshots; duplicate pack preserves the same package result. Packed goods remain accounted for before dispatch.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/pick-pack-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart [planned]
- apps/admin/lib/features/company/package_manifest_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/package_manifest.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/fulfillment_04.test.ts [planned]
- docs/task-results/FULFILLMENT-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No arbitrary destination branch from company tenant, reused package code silently, delivery or receipt settlement.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/fulfillment_04.test.ts
git diff --check -- firebase/functions/src/company/pick-pack-service.ts packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart apps/admin/lib/features/company/package_manifest_screen.dart packages/sarisupply_models/lib/src/company/package_manifest.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Pack, repeat the request and verify changed manifest under same ID rejects; inspect recipient store mapping.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/FULFILLMENT-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="fulfillment-05"></a>

### FULFILLMENT-05 — Release unshipped fulfillment work safely

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** FULFILLMENT-04, ORDERS-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only FULFILLMENT-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only FULFILLMENT-05: Release unshipped fulfillment work safely.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: FULFILLMENT-04, ORDERS-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/warehouse-fulfillment.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized Operations resolves eligible canceled/shorted unshipped work with compensating reservation and package state transitions; already dispatched goods require the delivery/return path. Audit quantities and reasons once.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/company/stock-reservation-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart [planned]
- apps/admin/lib/features/company/warehouse_fulfillment_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/company_stock_store.dart [planned]
- firebase/functions/src/company/pick-pack-service.ts [planned]
- apps/admin/lib/features/company/package_manifest_screen.dart [planned]
- packages/sarisupply_models/lib/src/company/package_manifest.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/fulfillment_05.test.ts [planned]
- docs/task-results/FULFILLMENT-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No silent cancellation of rider work, direct balance overwrite, destroying manifests or auto-restock of unreceived returns.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/fulfillment_05.test.ts
git diff --check -- firebase/functions/src/company/stock-reservation-service.ts packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart apps/admin/lib/features/company/warehouse_fulfillment_screen.dart packages/sarisupply_inventory/lib/src/company_stock_store.dart firebase/functions/src/company/pick-pack-service.ts apps/admin/lib/features/company/package_manifest_screen.dart packages/sarisupply_models/lib/src/company/package_manifest.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Release partial reservation, retry and attempt to release dispatched work; available stock changes once.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/FULFILLMENT-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="fulfillment-06"></a>

### FULFILLMENT-06 — Use the company fulfillment queue

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** FULFILLMENT-04, FULFILLMENT-05

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only FULFILLMENT-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only FULFILLMENT-06: Use the company fulfillment queue.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: FULFILLMENT-04, FULFILLMENT-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/warehouse-fulfillment.md. Read design.md before changing UI/copy.

Goal and acceptance:
Present scoped accepted/picking/packed/review queues with search/filter, one contextual action, real manifests and retained selections; refresh/error states preserve ongoing work. Wire only frozen existing actions.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/warehouse_fulfillment_screen.dart [planned]
- apps/admin/lib/features/company/package_manifest_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart [planned]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- docs/task-results/FULFILLMENT-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No new stock math, backend mutation policy, company internal financial dashboard or POS warehouse controls.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
git diff --check -- apps/admin/lib/features/company/warehouse_fulfillment_screen.dart apps/admin/lib/features/company/package_manifest_screen.dart packages/sarisupply_firebase/lib/src/functions/fulfillment_functions.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Filter orders, resume a package draft and refresh after failed request without duplicate action.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/FULFILLMENT-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="fulfillment-90"></a>

### FULFILLMENT-90 — Fulfillment integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** FULFILLMENT-01, FULFILLMENT-02, FULFILLMENT-03, FULFILLMENT-04, FULFILLMENT-05, FULFILLMENT-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only FULFILLMENT-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only FULFILLMENT-90: Fulfillment integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: FULFILLMENT-01, FULFILLMENT-02, FULFILLMENT-03, FULFILLMENT-04, FULFILLMENT-05, FULFILLMENT-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/warehouse-fulfillment.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all FULFILLMENT task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/FULFILLMENT-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/FULFILLMENT-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-tasks"></a>

## DELIVERY: Company dispatch and rider execution

<a id="delivery-01"></a>

### DELIVERY-01 — Freeze company delivery and proof contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** FULFILLMENT-04, AUTH-06, FULFILLMENT-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-01: Freeze company delivery and proof contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: FULFILLMENT-04, AUTH-06, FULFILLMENT-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Fix company/warehouse/rider/run/store-order/package scope, run/stop transitions, assigned-only reads, proof operation IDs, returned quantities and consented foreground GPS. Separate proof, receiving, collections and financial settlement.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/company-delivery.md [planned]
- docs/task-results/DELIVERY-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no automatic store stock mutation, paid maps, background tracking or merchant branch destinations.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/company-delivery.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace dispatch, removed rider, partial stop, duplicate proof, return and pending offline acknowledgement.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-02"></a>

### DELIVERY-02 — Select an active scoped rider from the roster

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-01, AUTH-11

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-02: Select an active scoped rider from the roster.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: DELIVERY-01, AUTH-11. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Operations sees named active riders authorized for its warehouse; assignment choices show current eligibility and revoked/inactive records disappear. Company Owner manages scope through established staff controls.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/company_riders_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart [planned]
- firebase/functions/src/company/company-membership-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- docs/task-results/DELIVERY-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No manager-created riders, raw UID input, new role grants or unrelated company/warehouse roster disclosure.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- apps/admin/lib/features/company/company_riders_screen.dart packages/sarisupply_firebase/lib/src/functions/company_membership_functions.dart firebase/functions/src/company/company-membership-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Open roster as one-warehouse manager, remove a rider and refresh eligibility without losing draft selections.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-03"></a>

### DELIVERY-03 — Create a draft run from packed manifests

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-02, FULFILLMENT-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-03: Create a draft run from packed manifests.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: DELIVERY-02, FULFILLMENT-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Operations chooses authorized rider, vehicle, packed packages and ordered destination stops; server validates immutable manifests/current assignment and reserves each package for one run. Stable run ID makes retry safe.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/company_dispatch_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart [planned]
- firebase/functions/src/company/delivery-service.ts [planned]
- packages/sarisupply_models/lib/src/delivery/delivery_run.dart [existing]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/delivery_03.test.ts [planned]
- docs/task-results/DELIVERY-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No fake stops, arbitrary product/cost payload, duplicate package assignment or store-selected company rider.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/delivery_03.test.ts
git diff --check -- apps/admin/lib/features/company/company_dispatch_screen.dart packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart firebase/functions/src/company/delivery-service.ts packages/sarisupply_models/lib/src/delivery/delivery_run.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Create a two-stop run, retry and reject another run claiming the same package.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-04"></a>

### DELIVERY-04 — Dispatch a verified company run

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-04: Dispatch a verified company run.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: DELIVERY-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Operations dispatches only an eligible draft run with current warehouse/rider/package state; record departure and in-transit company stock effects once. Show clear dispatch confirmation and failures retaining draft.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/company_dispatch_screen.dart [planned]
- packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart [planned]
- firebase/functions/src/company/delivery-service.ts [planned]
- packages/sarisupply_models/lib/src/delivery/delivery_run.dart [existing]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/delivery_04.test.ts [planned]
- docs/task-results/DELIVERY-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No silent reassignment, dispatch from Store Owner POS, receipt auto-confirmation or double warehouse debit.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/delivery_04.test.ts
git diff --check -- apps/admin/lib/features/company/company_dispatch_screen.dart packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart firebase/functions/src/company/delivery-service.ts packages/sarisupply_models/lib/src/delivery/delivery_run.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Dispatch, repeat, revoke rider before another dispatch and verify rejection retains reviewable draft.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-05"></a>

### DELIVERY-05 — Load assigned runs in Driver

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** DELIVERY-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only DELIVERY-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-05: Load assigned runs in Driver.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: DELIVERY-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Driver discovers current company/warehouse context and fetches only its assigned active work; durable local run cache supports approved offline use with explicit age/pending status. Switching workspace disposes stale routes.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/driver/lib/app/driver_app_gate.dart [existing]
- apps/driver/lib/features/delivery/presentation/driver_home_screen.dart [existing]
- apps/driver/lib/features/delivery/data/delivery_database.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart [planned]
- firebase/functions/src/company/delivery-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- firebase/functions/test/tasks/delivery_05.test.ts [planned]
- docs/task-results/DELIVERY-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No all-driver reads, demo route generation, copied UID enrollment or authorization beyond cached validity.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/delivery_05.test.ts
git diff --check -- apps/driver/lib/app/driver_app_gate.dart apps/driver/lib/features/delivery/presentation/driver_home_screen.dart apps/driver/lib/features/delivery/data/delivery_database.dart packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart firebase/functions/src/company/delivery-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart

Manual checks / observable acceptance:
Load own run, deny another rider, go offline and switch/sign out without losing queued evidence.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-06"></a>

### DELIVERY-06 — Navigate and record arrival at a stop

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-05

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-06: Navigate and record arrival at a stop.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: DELIVERY-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Assigned rider opens destination/contact/package context, launches installed Maps/call intent and records an allowed arrived event once. Handle missing coordinates/handler and retain correct stop on return.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/driver/lib/features/delivery/presentation/stop_detail_screen.dart [existing]
- apps/driver/lib/features/delivery/presentation/driver_home_screen.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart [planned]
- firebase/functions/src/company/delivery-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- docs/task-results/DELIVERY-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No paid embedded maps, bogus coordinate movement, contact beyond assigned work or delivery completion on arrival.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- apps/driver/lib/features/delivery/presentation/stop_detail_screen.dart apps/driver/lib/features/delivery/presentation/driver_home_screen.dart packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart firebase/functions/src/company/delivery-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart

Manual checks / observable acceptance:
Open Maps, return, mark arrival, deny access to unrelated stop and retry offline arrival.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-07"></a>

### DELIVERY-07 — Record actual delivery quantities and proof

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-07: Record actual delivery quantities and proof.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: DELIVERY-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Rider records delivered/returned quantities, recipient identity and signature against assigned manifest; local proof/items/outbox commit atomically. Server validates quantities and stable proof fingerprint, leaving store receipt pending.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/driver/lib/features/delivery/presentation/delivery_signature_screen.dart [existing]
- apps/driver/lib/features/delivery/presentation/signature_pad.dart [existing]
- packages/sarisupply_inventory/lib/src/company_delivery_store.dart [planned]
- firebase/functions/src/company/delivery-proof-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- firebase/functions/test/tasks/delivery_07.test.ts [planned]
- docs/task-results/DELIVERY-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No over-delivery, direct retailer stock write, cloud proof photos, duplicate finance or altered manifest unit costs.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/delivery_07.test.ts
git diff --check -- apps/driver/lib/features/delivery/presentation/delivery_signature_screen.dart apps/driver/lib/features/delivery/presentation/signature_pad.dart packages/sarisupply_inventory/lib/src/company_delivery_store.dart firebase/functions/src/company/delivery-proof-service.ts packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart

Manual checks / observable acceptance:
Deliver fully/partially, capture proof, restart and replay; wrong rider/changed payload reject.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-08"></a>

### DELIVERY-08 — Record failure and structured return reasons

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-08: Record failure and structured return reasons.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: DELIVERY-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Rider records failed or partially rejected stop with required reason and accounted goods; manifest quantities remain conserved and physical returns await warehouse receipt. Completion cannot imply paid or fully received.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/driver/lib/features/delivery/presentation/stop_detail_screen.dart [existing]
- apps/driver/lib/features/delivery/presentation/driver_home_screen.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart [planned]
- firebase/functions/src/company/delivery-service.ts [planned]
- apps/driver/lib/features/delivery/presentation/delivery_signature_screen.dart [existing]
- apps/driver/lib/features/delivery/presentation/signature_pad.dart [existing]
- packages/sarisupply_inventory/lib/src/company_delivery_store.dart [planned]
- firebase/functions/src/company/delivery-proof-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- firebase/functions/test/tasks/delivery_08.test.ts [planned]
- docs/task-results/DELIVERY-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No automatic restock, deleting failed stops, unsigned quantity inflation or collection on undelivered items without approved reason.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/delivery_08.test.ts
git diff --check -- apps/driver/lib/features/delivery/presentation/stop_detail_screen.dart apps/driver/lib/features/delivery/presentation/driver_home_screen.dart packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart firebase/functions/src/company/delivery-service.ts apps/driver/lib/features/delivery/presentation/delivery_signature_screen.dart apps/driver/lib/features/delivery/presentation/signature_pad.dart packages/sarisupply_inventory/lib/src/company_delivery_store.dart firebase/functions/src/company/delivery-proof-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart

Manual checks / observable acceptance:
Fail a stop, reject part of a package and verify run completion versus unresolved return status.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-09"></a>

### DELIVERY-09 — Synchronize durable Driver events

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-09: Synchronize durable Driver events.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: DELIVERY-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Preserve stable status/proof event IDs through offline restart and partial acknowledgements; server rechecks current assignment and accepted duplicates. Keep blocked/revoked evidence for explicit resolution instead of infinite retry or discard.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- packages/sarisupply_inventory/lib/src/company_delivery_store.dart [planned]
- apps/driver/lib/features/delivery/presentation/driver_home_screen.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart [planned]
- firebase/functions/src/company/delivery-proof-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- firebase/functions/test/tasks/delivery_09.test.ts [planned]
- docs/task-results/DELIVERY-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No stale authorization override, dropping unacknowledged proof, cross-rider upload or stock receipt side effects.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/delivery_09.test.ts
git diff --check -- packages/sarisupply_inventory/lib/src/company_delivery_store.dart apps/driver/lib/features/delivery/presentation/driver_home_screen.dart packages/sarisupply_firebase/lib/src/functions/company_delivery_functions.dart firebase/functions/src/company/delivery-proof-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart

Manual checks / observable acceptance:
Upload interrupted proof twice, remove assignment and inspect retained blocked evidence.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-10"></a>

### DELIVERY-10 — Share location explicitly while foregrounded

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** DELIVERY-05

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-10 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-10: Share location explicitly while foregrounded.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: DELIVERY-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Preserve approved opt-in GPS start/stop/update-now behavior for assigned active runs; background/lock pauses sharing and restart requires opt-in. Server rejects stale/out-of-order/cross-run samples.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/driver/lib/features/delivery/data/driver_gps.dart [existing]
- apps/driver/lib/features/delivery/presentation/driver_location_controller.dart [existing]
- apps/driver/lib/features/delivery/presentation/driver_location_card.dart [existing]
- firebase/functions/src/company/driver-location-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/driver_location_gateway.dart [existing]
- firebase/functions/src/https/commands.ts [existing]
- docs/task-results/DELIVERY-10.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No background service, fabricated live map, location history retention, paid maps or location permission bypass.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- apps/driver/lib/features/delivery/data/driver_gps.dart apps/driver/lib/features/delivery/presentation/driver_location_controller.dart apps/driver/lib/features/delivery/presentation/driver_location_card.dart firebase/functions/src/company/driver-location-service.ts packages/sarisupply_firebase/lib/src/functions/driver_location_gateway.dart firebase/functions/src/https/commands.ts

Manual checks / observable acceptance:
Grant/deny GPS, background to Maps, stop/restart and confirm truthful sharing/last-known labels.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-10.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-11"></a>

### DELIVERY-11 — View the latest permitted rider location

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** DELIVERY-10, DELIVERY-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only DELIVERY-11 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-11: View the latest permitted rider location.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: DELIVERY-10, DELIVERY-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner and scoped Operations view the latest authorized run snapshot with accuracy, age and sharing state; refresh and external Maps remain usable on phones. Retire POS dispatch location access for customer stores.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/driver_location_screen.dart [planned]
- apps/admin/lib/features/company/company_dispatch_screen.dart [planned]
- firebase/functions/src/company/driver-location-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/driver_location_gateway.dart [existing]
- firebase/functions/src/https/commands.ts [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/delivery_11.test.ts [planned]
- docs/task-results/DELIVERY-11.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No platform-wide tracking, continuous location promise, raw location history or unrelated warehouse rider visibility.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/delivery_11.test.ts
git diff --check -- apps/admin/lib/features/company/driver_location_screen.dart apps/admin/lib/features/company/company_dispatch_screen.dart firebase/functions/src/company/driver-location-service.ts packages/sarisupply_firebase/lib/src/functions/driver_location_gateway.dart firebase/functions/src/https/commands.ts apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Read own warehouse active run, deny another manager and show stale/paused samples as last known.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-11.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="delivery-90"></a>

### DELIVERY-90 — Delivery integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** DELIVERY-01, DELIVERY-02, DELIVERY-03, DELIVERY-04, DELIVERY-05, DELIVERY-06, DELIVERY-07, DELIVERY-08, DELIVERY-09, DELIVERY-10, DELIVERY-11

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only DELIVERY-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only DELIVERY-90: Delivery integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: DELIVERY-01, DELIVERY-02, DELIVERY-03, DELIVERY-04, DELIVERY-05, DELIVERY-06, DELIVERY-07, DELIVERY-08, DELIVERY-09, DELIVERY-10, DELIVERY-11. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/company-delivery.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all DELIVERY task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/DELIVERY-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/DELIVERY-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-tasks"></a>

## SETTLEMENT: Actual receiving, returns, collection and remittance

<a id="settlement-01"></a>

### SETTLEMENT-01 — Freeze independent receiving and settlement contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** DELIVERY-09, FULFILLMENT-01, DELIVERY-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-01: Freeze independent receiving and settlement contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: DELIVERY-09, FULFILLMENT-01, DELIVERY-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define store receipt IDs, confirmed quantities/mappings, per-business durable acceptance, discrepancy resolution, return disposition, collection/remittance facts and payment accounting. Specify replay/partial-failure convergence and immutable compensation.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/receiving-settlement.md [planned]
- docs/task-results/SETTLEMENT-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no two independent ledgers treated as one, company auto-receipt, balance overwrite or unapproved payment provider.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/receiving-settlement.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Walk proof with disputed quantities, duplicate receiving, restock versus quarantine and collected-but-unremitted cash.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-02"></a>

### SETTLEMENT-02 — Confirm actual company-order goods in POS

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETTLEMENT-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-02: Confirm actual company-order goods in POS.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized Store Owner/receiving Manager reviews delivered package and confirms accepted quantities; persist stable receiving intent and apply store stock once through explicit product/unit mapping. Company sees receipt confirmation without write access to retail data.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/order_receiving_screen.dart [planned]
- packages/sarisupply_inventory/lib/src/store_order_store.dart [planned]
- firebase/functions/src/company/store-receiving-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/store_receiving_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- firebase/functions/test/tasks/settlement_02.test.ts [planned]
- docs/task-results/SETTLEMENT-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No cashier-only receiving grant, full receipt inferred from signature, double company debit or silent disputed quantity acceptance.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/settlement_02.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/order_receiving_screen.dart packages/sarisupply_inventory/lib/src/store_order_store.dart firebase/functions/src/company/store-receiving-service.ts packages/sarisupply_firebase/lib/src/functions/store_receiving_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Confirm full/partial goods offline, retry online twice and verify only accepted quantities enter retail stock.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-03"></a>

### SETTLEMENT-03 — Open and resolve a delivery discrepancy

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETTLEMENT-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-03: Open and resolve a delivery discrepancy.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store recipient and company Operations record their respective shortage/damage evidence and resolve the exact disputed quantities with auditable compensating entries. Keep unresolved goods and financial effects visible.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/inventory/presentation/order_discrepancy_screen.dart [planned]
- apps/admin/lib/features/company/order_discrepancy_screen.dart [planned]
- firebase/functions/src/company/discrepancy-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/discrepancy_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/settlement_03.test.ts [planned]
- docs/task-results/SETTLEMENT-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unilateral retailer receipt edits, historical proof mutation, silent write-off or auto-close when route ends.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/settlement_03.test.ts
git diff --check -- apps/pos/lib/features/inventory/presentation/order_discrepancy_screen.dart apps/admin/lib/features/company/order_discrepancy_screen.dart firebase/functions/src/company/discrepancy-service.ts packages/sarisupply_firebase/lib/src/functions/discrepancy_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Dispute one quantity, reject unauthorized resolution and verify agreed resolution produces one adjustment.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-04"></a>

### SETTLEMENT-04 — Receive returned goods at the warehouse

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETTLEMENT-01, DELIVERY-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-04: Receive returned goods at the warehouse.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-01, DELIVERY-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Scoped warehouse staff confirms physical returned quantities against run/package return facts with stable receiving ID; only received approved quantities move from return transit into disposition.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/warehouse_returns_screen.dart [planned]
- firebase/functions/src/company/delivery-return-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_return_functions.dart [planned]
- packages/sarisupply_inventory/lib/src/company_stock_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/settlement_04.test.ts [planned]
- docs/task-results/SETTLEMENT-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No inventory availability before physical receipt, over-return, deleting proof or store-owner warehouse access.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/settlement_04.test.ts
git diff --check -- apps/admin/lib/features/company/warehouse_returns_screen.dart firebase/functions/src/company/delivery-return-service.ts packages/sarisupply_firebase/lib/src/functions/company_return_functions.dart packages/sarisupply_inventory/lib/src/company_stock_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Receive a partial return, repeat operation and reject quantity beyond documented return.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-05"></a>

### SETTLEMENT-05 — Restock or quarantine received returns

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETTLEMENT-04

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-05: Restock or quarantine received returns.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-04. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized Operations chooses reasoned restock/quarantine disposition; exactly one movement changes available or quarantined company stock. Later correction uses auditable compensation rather than changing original event.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/warehouse_returns_screen.dart [planned]
- firebase/functions/src/company/delivery-return-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_return_functions.dart [planned]
- packages/sarisupply_inventory/lib/src/company_stock_store.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/settlement_05.test.ts [planned]
- docs/task-results/SETTLEMENT-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No damaged stock silently sellable, disposition replay duplication, branch retail credit or automatic cash refund.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/settlement_05.test.ts
git diff --check -- apps/admin/lib/features/company/warehouse_returns_screen.dart firebase/functions/src/company/delivery-return-service.ts packages/sarisupply_firebase/lib/src/functions/company_return_functions.dart packages/sarisupply_inventory/lib/src/company_stock_store.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Restock one item, quarantine another and replay both without duplicate availability.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-06"></a>

### SETTLEMENT-06 — Record and review rider cash collection

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETTLEMENT-01, DELIVERY-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-06: Record and review rider cash collection.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-01, DELIVERY-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Rider records allowed cash collection linked to order/proof and immutable operation; Operations reviews expected-versus-recorded collection. Pending collection and reconciliation status do not imply warehouse remittance.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/driver/lib/features/delivery/presentation/collection_screen.dart [planned]
- apps/admin/lib/features/company/collection_review_screen.dart [planned]
- firebase/functions/src/company/collection-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/collection_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- firebase/functions/test/tasks/settlement_06.test.ts [planned]
- docs/task-results/SETTLEMENT-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No free-form unrelated cash, auto-paid from stop completion, editable settled collection or company trade-credit scheme.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/settlement_06.test.ts
git diff --check -- apps/driver/lib/features/delivery/presentation/collection_screen.dart apps/admin/lib/features/company/collection_review_screen.dart firebase/functions/src/company/collection-service.ts packages/sarisupply_firebase/lib/src/functions/collection_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Record collection, retry and show discrepancy without marking remitted; deny another rider's collection.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-07"></a>

### SETTLEMENT-07 — Confirm rider cash remittance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETTLEMENT-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-07: Confirm rider cash remittance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized company staff confirms physical remittance against rider outstanding collections with stable event and reasoned discrepancy; rider can view own acknowledged remittance history. Company Owner retains financial oversight.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/rider_remittance_screen.dart [planned]
- apps/driver/lib/features/delivery/presentation/remittance_history_screen.dart [planned]
- firebase/functions/src/company/remittance-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/remittance_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- firebase/functions/test/tasks/settlement_07.test.ts [planned]
- docs/task-results/SETTLEMENT-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No rider self-approval, collecting store retail cash, editing prior remittance or double-settling same collection.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/settlement_07.test.ts
git diff --check -- apps/admin/lib/features/company/rider_remittance_screen.dart apps/driver/lib/features/delivery/presentation/remittance_history_screen.dart firebase/functions/src/company/remittance-service.ts packages/sarisupply_firebase/lib/src/functions/remittance_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Remit partially/fully, retry and verify outstanding balance plus wrong-warehouse denial.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-08"></a>

### SETTLEMENT-08 — Reconcile company order payment evidence

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** SETTLEMENT-02, SETTLEMENT-06, SETTLEMENT-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-08: Reconcile company order payment evidence.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-02, SETTLEMENT-06, SETTLEMENT-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Record cash/manual QR payment and compensating adjustments linked to confirmed order/receipt; display store-visible commercial payment history and company reconciliation separately from retail sales. Stable IDs prevent duplicate settlement.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/order_payment_screen.dart [planned]
- apps/pos/lib/features/inventory/presentation/order_payment_history_screen.dart [planned]
- firebase/functions/src/company/order-payment-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/order_payment_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/settlement_08.test.ts [planned]
- docs/task-results/SETTLEMENT-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No provider verification claim, new gateway, hidden wholesale credit or bank credential access.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/settlement_08.test.ts
git diff --check -- apps/admin/lib/features/company/order_payment_screen.dart apps/pos/lib/features/inventory/presentation/order_payment_history_screen.dart firebase/functions/src/company/order-payment-service.ts packages/sarisupply_firebase/lib/src/functions/order_payment_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Confirm manual QR reference, replay cash evidence and reconcile a partial receipt with explicit outstanding amount.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="settlement-90"></a>

### SETTLEMENT-90 — Settlement integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** SETTLEMENT-01, SETTLEMENT-02, SETTLEMENT-03, SETTLEMENT-04, SETTLEMENT-05, SETTLEMENT-06, SETTLEMENT-07, SETTLEMENT-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only SETTLEMENT-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only SETTLEMENT-90: Settlement integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: SETTLEMENT-01, SETTLEMENT-02, SETTLEMENT-03, SETTLEMENT-04, SETTLEMENT-05, SETTLEMENT-06, SETTLEMENT-07, SETTLEMENT-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/receiving-settlement.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all SETTLEMENT task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/SETTLEMENT-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/SETTLEMENT-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-tasks"></a>

## REPORTS: Scoped reporting, alerts and export

<a id="reports-01"></a>

### REPORTS-01 — Freeze reporting scopes and sources

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** POS-11, SETTLEMENT-08, ORDERS-02, SETTLEMENT-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-01: Freeze reporting scopes and sources.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-11, SETTLEMENT-08, ORDERS-02, SETTLEMENT-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define store retail versus company wholesale measures, accepted versus local/pending sources, branch/warehouse scope, missing cost handling and consented summary contracts. Specify bounded pagination, business dates and export fields without legal certification claims.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/reports-alerts.md [planned]
- docs/task-results/REPORTS-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no network-wide retail access by Company Owner, invented tax policy or unsupported financial totals.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/reports-alerts.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Compare one POS device's cache with accepted store totals and company collections/remittance totals.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-02"></a>

### REPORTS-02 — Show branch and store retail sales reports

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** REPORTS-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-02: Show branch and store retail sales reports.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: REPORTS-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store Owner/scoped Manager views correct accepted or clearly labeled local gross/net/tender/refund/void/credit measures using existing ledger math and business dates. Permission and branch scope are checked on reads.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/reports/presentation/reports_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- packages/sarisupply_models/lib/src/reports/sales_report.dart [existing]
- firebase/functions/src/management/store-report-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/test/tasks/reports_02.test.ts [planned]
- docs/task-results/REPORTS-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No company customers' retail data, double-decoded shifts, broad Platform Admin reports or cached device totals labeled store-wide.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/reports_02.test.ts
git diff --check -- apps/pos/lib/features/reports/presentation/reports_screen.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_inventory/lib/src/inventory_store.dart packages/sarisupply_models/lib/src/reports/sales_report.dart firebase/functions/src/management/store-report-service.ts firebase/functions/src/https/commands.ts

Manual checks / observable acceptance:
Compare two devices/branches, cash versus QR refund and missing accepted summary.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-03"></a>

### REPORTS-03 — Show an honest Store Owner overview

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** REPORTS-02

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only REPORTS-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-03: Show an honest Store Owner overview.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: REPORTS-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Reuse approved Overview/Branches/Team/Devices navigation; overview identifies selected branch, source/freshness, stock shortages and direct report/catalog actions. Preserve useful phone hierarchy without invented statistics.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/management/presentation/store_overview_screen.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/store_report_functions.dart [planned]
- firebase/functions/src/management/store-report-service.ts [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- docs/task-results/REPORTS-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No new financial formulas, reporting schema, whole-navigation redesign or company operations widgets.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- apps/pos/lib/features/management/presentation/store_overview_screen.dart packages/sarisupply_firebase/lib/src/functions/store_report_functions.dart firebase/functions/src/management/store-report-service.ts firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart

Manual checks / observable acceptance:
Open at 320/390 width and 200-percent text; switch branch and view offline device-only totals.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-04"></a>

### REPORTS-04 — Show company wholesale sales and settlement reports

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** REPORTS-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-04: Show company wholesale sales and settlement reports.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: REPORTS-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Owner sees accepted wholesale sales, returns, payments, collections, remittances and outstanding discrepancies; managers see only permitted operational queues. Separate order, delivery and financial settlement status.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/company_reports_screen.dart [planned]
- firebase/functions/src/company/report-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_report_functions.dart [planned]
- packages/sarisupply_models/lib/src/company/company_report.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/reports_04.test.ts [planned]
- docs/task-results/REPORTS-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No summing retail receipts into company revenue, fake cost margins, blanket manager finance access or implicit paid orders.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/reports_04.test.ts
git diff --check -- apps/admin/lib/features/company/company_reports_screen.dart firebase/functions/src/company/report-service.ts packages/sarisupply_firebase/lib/src/functions/company_report_functions.dart packages/sarisupply_models/lib/src/company/company_report.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Trace one partial order and rider remittance; confirm store/platform-only users cannot read internal company totals.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-05"></a>

### REPORTS-05 — Show inventory valuation with missing-cost states

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** REPORTS-02, REPORTS-04, PURCHASING-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-05: Show inventory valuation with missing-cost states.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: REPORTS-02, REPORTS-04, PURCHASING-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Compute separate store and company valuation from owned stock and explicit cost provenance; unknown cost stays unavailable, not zero or suggested retail price. Report product movements and scope without combining separate businesses.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/reports/presentation/reports_screen.dart [existing]
- packages/sarisupply_inventory/lib/src/checkout_store.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- packages/sarisupply_models/lib/src/reports/sales_report.dart [existing]
- firebase/functions/src/management/store-report-service.ts [planned]
- apps/admin/lib/features/company/company_reports_screen.dart [planned]
- firebase/functions/src/company/report-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_report_functions.dart [planned]
- packages/sarisupply_models/lib/src/company/company_report.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/reports_05.test.ts [planned]
- docs/task-results/REPORTS-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No fabricated margins, wholesale cost disclosure to customer stores or rewriting cost snapshots.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/reports_05.test.ts
git diff --check -- apps/pos/lib/features/reports/presentation/reports_screen.dart packages/sarisupply_inventory/lib/src/checkout_store.dart packages/sarisupply_inventory/lib/src/inventory_store.dart packages/sarisupply_models/lib/src/reports/sales_report.dart firebase/functions/src/management/store-report-service.ts apps/admin/lib/features/company/company_reports_screen.dart firebase/functions/src/company/report-service.ts packages/sarisupply_firebase/lib/src/functions/company_report_functions.dart packages/sarisupply_models/lib/src/company/company_report.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Value known/unknown costs and quarantine/returns; confirm authorized scope and no duplicated movements.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-06"></a>

### REPORTS-06 — Show consented replenishment insights

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** REPORTS-01, ORDERS-02

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-06: Show consented replenishment insights.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: REPORTS-01, ORDERS-02. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Company Operations sees only authorized stock/sales summaries needed for assigned customer-order work with freshness and consent scope; current server checks deny revoked categories and no consent means unavailable.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/replenishment_insights_screen.dart [planned]
- firebase/functions/src/company/insight-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_insight_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/reports_06.test.ts [planned]
- docs/task-results/REPORTS-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No receipts/customer details, cached revoked access revival, rider access or use outside replenishment purpose.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/reports_06.test.ts
git diff --check -- apps/admin/lib/features/company/replenishment_insights_screen.dart firebase/functions/src/company/insight-service.ts packages/sarisupply_firebase/lib/src/functions/company_insight_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Enable stock-only sharing, deny sales, revoke and inspect discarded cached summaries on refresh.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-07"></a>

### REPORTS-07 — Show actionable store stock and sync alerts

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RETAIL-05, CATALOG-09, POS-11

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-07: Show actionable store stock and sync alerts.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: RETAIL-05, CATALOG-09, POS-11. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Store alerts identify real shortage/expiry/sync-conflict states and deep-link to authorized existing recovery screens. Pending counts and dismissed/read state remain durable and scope-correct.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/notifications/presentation/notification_bell.dart [existing]
- packages/sarisupply_inventory/lib/src/inventory_store.dart [existing]
- packages/sarisupply_models/lib/src/reports/notification.dart [existing]
- docs/task-results/REPORTS-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No fake stock urgency, auto-purchase, promotional notifications, new push provider or hidden errors.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
git diff --check -- apps/pos/lib/features/notifications/presentation/notification_bell.dart packages/sarisupply_inventory/lib/src/inventory_store.dart packages/sarisupply_models/lib/src/reports/notification.dart

Manual checks / observable acceptance:
Trigger low stock/expiry/blocked sync and follow each action while offline and at narrow width.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-08"></a>

### REPORTS-08 — Show scoped company operations alerts

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** FULFILLMENT-06, SETTLEMENT-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only REPORTS-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-08: Show scoped company operations alerts.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: FULFILLMENT-06, SETTLEMENT-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized company staff sees actionable overdue/shorted/failed/return/remittance review queues based on actual records; links respect warehouse scope and do not leak company-wide finance to managers.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/admin/lib/features/company/company_alerts_screen.dart [planned]
- firebase/functions/src/company/alert-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/company_alert_functions.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/reports_08.test.ts [planned]
- docs/task-results/REPORTS-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No fabricated deadlines, retail customer info, background rider surveillance or paid notification service.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/reports_08.test.ts
git diff --check -- apps/admin/lib/features/company/company_alerts_screen.dart firebase/functions/src/company/alert-service.ts packages/sarisupply_firebase/lib/src/functions/company_alert_functions.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Open failed delivery and outstanding return as scoped manager; verify Owner-only financial alert detail.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-09"></a>

### REPORTS-09 — Export scoped reports as real files

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** REPORTS-02, REPORTS-04, REPORTS-05

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-09: Export scoped reports as real files.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: REPORTS-02, REPORTS-04, REPORTS-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Export authorized report data using existing CSV escaping, explicit scope/source/date metadata and real save/share confirmation; protect against spreadsheet formula injection. Handle permission/disk cancellation honestly.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/reports/presentation/report_export_screen.dart [planned]
- apps/admin/lib/features/company/report_export_screen.dart [planned]
- packages/sarisupply_models/lib/src/reports/csv_export.dart [planned]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- docs/task-results/REPORTS-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No raw private retail dump, synthetic totals, export-success toast without artifact or extra cloud storage.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
git diff --check -- apps/pos/lib/features/reports/presentation/report_export_screen.dart apps/admin/lib/features/company/report_export_screen.dart packages/sarisupply_models/lib/src/reports/csv_export.dart packages/sarisupply_models/lib/sarisupply_models.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Export quoted/newline/formula-like values, cancel share and reopen file to compare report values.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="reports-90"></a>

### REPORTS-90 — Reports integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** REPORTS-01, REPORTS-02, REPORTS-03, REPORTS-04, REPORTS-05, REPORTS-06, REPORTS-07, REPORTS-08, REPORTS-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only REPORTS-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only REPORTS-90: Reports integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: REPORTS-01, REPORTS-02, REPORTS-03, REPORTS-04, REPORTS-05, REPORTS-06, REPORTS-07, REPORTS-08, REPORTS-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/reports-alerts.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all REPORTS task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/REPORTS-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/REPORTS-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-tasks"></a>

## RECOVERY: Printing, archives and recovery

<a id="recovery-01"></a>

### RECOVERY-01 — Freeze archive, recovery and printer contracts

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** POS-11, SETTLEMENT-08, REPORTS-01, SETTLEMENT-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RECOVERY-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-01: Freeze archive, recovery and printer contracts.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: POS-11, SETTLEMENT-08, REPORTS-01, SETTLEMENT-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Inventory all new local/company/store tables and pending facts; define complete encrypted snapshots, isolated restore validation, replay-safe recovery and printer capability/result semantics. Preserve existing encryption and key separation.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/recovery-printing.md [planned]
- docs/task-results/RECOVERY-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no weaker encryption, cloud storage bucket, snapshot excluding outboxes or claim printer bytes equal printed paper.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/recovery-printing.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace archive with pending sale/order/proof, wrong password, interrupted restore and unavailable printer.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-02"></a>

### RECOVERY-02 — Record and validate the real printer hardware

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** contract · **Dependencies:** RECOVERY-01

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RECOVERY-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-02: Record and validate the real printer hardware.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: RECOVERY-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md.

Goal and acceptance:
Record user-supplied printer model, paper width and supported connection transport; validate one selected existing-compatible device and permissions before transport implementation. Produce an exact adapter/acceptance contract.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/printer-hardware.md [planned]
- docs/task-results/RECOVERY-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No inventing hardware, purchasing device, implementing every transport or marking unavailable hardware accepted.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/printer-hardware.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Identify available printer and demonstrate a physical connection; otherwise record the external blocker with required input.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-03"></a>

### RECOVERY-03 — Configure and print through one real transport

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** RECOVERY-02, POS-07

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RECOVERY-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-03: Configure and print through one real transport.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RECOVERY-02, POS-07. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Implement only the transport selected in the printer contract, with connection/permission recovery and saved settings; use existing formatter/ESC-POS bytes. UI reports sent versus physically verified print honestly.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/reports/presentation/printer_settings_screen.dart [planned]
- apps/pos/lib/features/reports/presentation/receipt_preview_dialog.dart [existing]
- packages/sarisupply_core/lib/src/printing/printer_transport.dart [planned]
- packages/sarisupply_core/lib/src/printing/receipt_formatter.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/pos/test/tasks/recovery_03_test.dart [planned]
- docs/task-results/RECOVERY-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No extra transports, paid print service, fake success, financial sale replay to reprint or unneeded dependency.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_core && flutter analyze)
(cd apps/pos && flutter test test/tasks/recovery_03_test.dart)
git diff --check -- apps/pos/lib/features/reports/presentation/printer_settings_screen.dart apps/pos/lib/features/reports/presentation/receipt_preview_dialog.dart packages/sarisupply_core/lib/src/printing/printer_transport.dart packages/sarisupply_core/lib/src/printing/receipt_formatter.dart apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Print one actual receipt, disconnect/cancel/retry and verify correct paper/unit/centavo text.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-04"></a>

### RECOVERY-04 — Reprint a receipt or closed-shift summary

**Model:** `gpt-6-luna` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** RECOVERY-03, POS-09

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RECOVERY-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-04: Reprint a receipt or closed-shift summary.
Use model gpt-6-luna with reasoning medium; select it before starting.
Dependencies: RECOVERY-03, POS-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized store user previews/reprints existing immutable receipt or closed-shift summary with original scope/date and clear copy label; printer failure does not change finance.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/reports/presentation/printer_settings_screen.dart [planned]
- apps/pos/lib/features/reports/presentation/receipt_preview_dialog.dart [existing]
- packages/sarisupply_core/lib/src/printing/printer_transport.dart [planned]
- packages/sarisupply_core/lib/src/printing/receipt_formatter.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- docs/task-results/RECOVERY-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No new total formulas, legal receipt certification, opening cash drawer automatically on reprint or claiming unconfirmed print.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_core && flutter analyze)
git diff --check -- apps/pos/lib/features/reports/presentation/printer_settings_screen.dart apps/pos/lib/features/reports/presentation/receipt_preview_dialog.dart packages/sarisupply_core/lib/src/printing/printer_transport.dart packages/sarisupply_core/lib/src/printing/receipt_formatter.dart apps/pos/lib/app/pos_app_gate.dart

Manual checks / observable acceptance:
Reprint a past receipt and summary, deny unrelated store and fail printer without new sale/cash event.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-05"></a>

### RECOVERY-05 — Export a complete encrypted business archive

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RECOVERY-01, SETTLEMENT-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RECOVERY-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-05: Export a complete encrypted business archive.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RECOVERY-01, SETTLEMENT-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Authorized owner exports consistent business-scoped snapshots with all local tables and durable pending intents/cursors; preserve existing authenticated encryption and manifests. Company and store archives are distinguished and secrets stay separate.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- packages/sarisupply_inventory/lib/src/archival/backup_archive_service.dart [existing]
- apps/pos/lib/features/reports/presentation/backup_archive_screen.dart [planned]
- apps/admin/lib/features/company/company_archive_screen.dart [planned]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- packages/sarisupply_inventory/test/tasks/recovery_05_test.dart [planned]
- docs/task-results/RECOVERY-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No cloud credential export, plaintext backup, excluded pending orders/proofs or archive as device grant transfer.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_inventory && flutter test test/tasks/recovery_05_test.dart)
git diff --check -- packages/sarisupply_inventory/lib/src/archival/backup_archive_service.dart apps/pos/lib/features/reports/presentation/backup_archive_screen.dart apps/admin/lib/features/company/company_archive_screen.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Export store/company snapshots including pending work, reopen manifest and verify record scope/count.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-06"></a>

### RECOVERY-06 — Verify an archive before restoring it

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RECOVERY-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RECOVERY-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-06: Verify an archive before restoring it.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RECOVERY-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Validate password, authenticated ciphertext, manifest scope/version/count/schema and owned business context in isolation; corrupted/unknown archives yield safe errors without modifying active workspace.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- packages/sarisupply_inventory/lib/src/archival/backup_archive_service.dart [existing]
- apps/pos/lib/features/reports/presentation/backup_archive_screen.dart [planned]
- apps/admin/lib/features/company/company_archive_screen.dart [planned]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- packages/sarisupply_inventory/test/tasks/recovery_06_test.dart [planned]
- docs/task-results/RECOVERY-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No fallback to untrusted plaintext, weaker legacy crypto, automatic replace or treating matching filename as scope evidence.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_inventory && flutter test test/tasks/recovery_06_test.dart)
git diff --check -- packages/sarisupply_inventory/lib/src/archival/backup_archive_service.dart apps/pos/lib/features/reports/presentation/backup_archive_screen.dart apps/admin/lib/features/company/company_archive_screen.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Try valid/wrong password, corrupt bytes, wrong business and unsupported version; active data remains unchanged.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-07"></a>

### RECOVERY-07 — Restore into an isolated empty workspace

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RECOVERY-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RECOVERY-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-07: Restore into an isolated empty workspace.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RECOVERY-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Restore only into an empty validated workspace, check schema/integrity, retain pending operation IDs and require fresh device authorization before POS use. Interrupted restore never overwrites an occupied business database.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- packages/sarisupply_inventory/lib/src/archival/backup_archive_service.dart [existing]
- apps/pos/lib/features/diagnostics/presentation/diagnostic_recovery_screen.dart [existing]
- packages/sarisupply_core/lib/src/diagnostics/system_diagnostics_service.dart [existing]
- packages/sarisupply_inventory/test/tasks/recovery_07_test.dart [planned]
- docs/task-results/RECOVERY-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No restoring active grants, replacing occupied workspace, pending-event regeneration or immediate production cutover.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_core && flutter analyze)
(cd packages/sarisupply_inventory && flutter analyze)
(cd packages/sarisupply_inventory && flutter test test/tasks/recovery_07_test.dart)
git diff --check -- packages/sarisupply_inventory/lib/src/archival/backup_archive_service.dart apps/pos/lib/features/diagnostics/presentation/diagnostic_recovery_screen.dart packages/sarisupply_core/lib/src/diagnostics/system_diagnostics_service.dart

Manual checks / observable acceptance:
Restore, interrupt and retry; confirm totals/outboxes match and fresh device activation is required.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-08"></a>

### RECOVERY-08 — Archive settled records before retention deletion

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RECOVERY-05, REPORTS-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RECOVERY-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-08: Archive settled records before retention deletion.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RECOVERY-05, REPORTS-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Implement a bounded preview/approval flow for eligible settled records after the approved retention period; unresolved operations and balances remain online. Require verified restore and two owner-controlled archive copies before deletion.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/maintenance/retention-service.ts [planned]
- packages/sarisupply_firebase/lib/src/functions/archive_functions.dart [planned]
- apps/admin/lib/features/company/retention_review_screen.dart [planned]
- firebase/functions/src/https/commands.ts [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- firebase/functions/test/tasks/recovery_08.test.ts [planned]
- docs/task-results/RECOVERY-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No deleting young/unsettled data, unapproved live purge, paid backups or one-copy deletion shortcut.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/recovery_08.test.ts
git diff --check -- firebase/functions/src/maintenance/retention-service.ts packages/sarisupply_firebase/lib/src/functions/archive_functions.dart apps/admin/lib/features/company/retention_review_screen.dart firebase/functions/src/https/commands.ts packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/admin/lib/app/admin_app_gate.dart

Manual checks / observable acceptance:
Preview eligibility, block missing copies/restore evidence and rehearse deletion only against isolated fixtures.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-09"></a>

### RECOVERY-09 — Inspect blocked local work without losing it

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** POS-11, ORDERS-08, DELIVERY-09

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RECOVERY-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-09: Inspect blocked local work without losing it.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: POS-11, ORDERS-08, DELIVERY-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Diagnostics shows safe pending/conflict/blocked counts and operation details, reason-specific retry and isolated archive recovery paths. Preserve immutable payload/IDs; clear authority before denied access recovery without clearing finance.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/lib/features/diagnostics/presentation/diagnostic_recovery_screen.dart [existing]
- packages/sarisupply_firebase/lib/src/functions/operation_error_message.dart [existing]
- docs/task-results/RECOVERY-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No blanket reset, exposing secrets, silent resend of changed payload or treating permanent denial as network failure.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
git diff --check -- apps/pos/lib/features/diagnostics/presentation/diagnostic_recovery_screen.dart packages/sarisupply_firebase/lib/src/functions/operation_error_message.dart

Manual checks / observable acceptance:
Inspect blocked sale/order/proof, retry a transient error and verify malformed evidence is preserved for review.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="recovery-90"></a>

### RECOVERY-90 — Recovery integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** RECOVERY-01, RECOVERY-02, RECOVERY-03, RECOVERY-04, RECOVERY-05, RECOVERY-06, RECOVERY-07, RECOVERY-08, RECOVERY-09

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RECOVERY-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RECOVERY-90: Recovery integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RECOVERY-01, RECOVERY-02, RECOVERY-03, RECOVERY-04, RECOVERY-05, RECOVERY-06, RECOVERY-07, RECOVERY-08, RECOVERY-09. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/recovery-printing.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all RECOVERY task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/RECOVERY-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RECOVERY-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-tasks"></a>

## RELEASE: Migration, full acceptance and production readiness

<a id="release-01"></a>

### RELEASE-01 — Freeze final acceptance and release evidence

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** contract · **Dependencies:** RECOVERY-01

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-01 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-01: Freeze final acceptance and release evidence.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RECOVERY-01. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs.

Goal and acceptance:
Define Development and Production evidence checklists, signed build settings, free capacity limits, full-platform pilot gate, external prerequisites and rollback criteria. List exact fixture accounts/roles without credentials and separate deployment approval from local completion.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/release-acceptance.md [planned]
- docs/task-results/RELEASE-01.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no publication, paid fallback, real pilot or deployment approval inferred from task completion.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/release-acceptance.md
git status --short
Validate referenced local document links and dependency contracts; no app build is needed for documentation alone.

Manual checks / observable acceptance:
Trace every canonical actor and feature group to a measurable acceptance gate and identify external blockers.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-01.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-02"></a>

### RELEASE-02 — Dry-run the legacy architecture migration

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RELEASE-01, RECOVERY-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-02 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-02: Dry-run the legacy architecture migration.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RELEASE-01, RECOVERY-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Inventory legacy merchant warehouses/riders/manifests and pending SQLite events; produce explicit company/store/warehouse/product mapping and non-mutating migration preview. Reject ambiguous ownership and specify preserved IDs/history plus rollback.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/maintenance/architecture-migration.ts [planned]
- packages/sarisupply_inventory/lib/src/architecture_migration.dart [planned]
- docs/task-contracts/architecture-migration.md [planned]
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/test/tasks/release_02.test.ts [planned]
- docs/task-results/RELEASE-02.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No relabeling customer stores as company branches, destructive schema reset, client-secret migration or live writes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/release_02.test.ts
git diff --check -- firebase/functions/src/maintenance/architecture-migration.ts packages/sarisupply_inventory/lib/src/architecture_migration.dart docs/task-contracts/architecture-migration.md firebase/functions/src/https/commands.ts

Manual checks / observable acceptance:
Preview representative legacy data with pending finance; inspect ambiguous mappings and compare before/after counts.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-02.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-03"></a>

### RELEASE-03 — Rehearse and validate data-preserving migration

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RELEASE-02, RECOVERY-07, RETAIL-90, REPORTS-90, RECOVERY-90

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-03 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-03: Rehearse and validate data-preserving migration.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RELEASE-02, RECOVERY-07, RETAIL-90, REPORTS-90, RECOVERY-90. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Apply the approved migration only to isolated Development/emulator copies; additive steps resume/replay safely and preserve immutable finance, pending IDs, units and access boundaries. Validate rollback/restore before any real cutover is proposed.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/maintenance/architecture-migration.ts [planned]
- packages/sarisupply_inventory/lib/src/architecture_migration.dart [planned]
- docs/task-contracts/architecture-migration.md [planned]
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/test/tasks/release_03.test.ts [planned]
- docs/task-results/RELEASE-03.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No production mutation, dropping legacy queues, inventing missing ownership or overwriting occupied local workspaces.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
(cd packages/sarisupply_inventory && flutter analyze)
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/release_03.test.ts
git diff --check -- firebase/functions/src/maintenance/architecture-migration.ts packages/sarisupply_inventory/lib/src/architecture_migration.dart docs/task-contracts/architecture-migration.md firebase/functions/src/https/commands.ts

Manual checks / observable acceptance:
Interrupt/repeat migration; compare stock/finance/outboxes and deny old endpoints bypassing new business scope.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-03.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-04"></a>

### RELEASE-04 — Run final role and tenancy security acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** acceptance · **Dependencies:** RELEASE-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-04 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-04: Run final role and tenancy security acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RELEASE-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Execute the comprehensive Development-only actor/role/warehouse/store/branch/device/invitation/revocation tests after all feature groups are integrated. Check legacy endpoints, App Check/token environment and default-deny rules; record failures and focused repairs.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/release-acceptance.md [planned]
- docs/task-results/RELEASE-04.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No Production tests, bypassed attestation, exposing secrets or declaring security pass from static analysis alone.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/release-acceptance.md
bash tool/verify_firebase.sh

Manual checks / observable acceptance:
Verify every permission-denial matrix cell and removed rider/device reconnect case with real server authorization.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-04.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-05"></a>

### RELEASE-05 — Run final offline, replay and crash acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** acceptance · **Dependencies:** RELEASE-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-05 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-05: Run final offline, replay and crash acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RELEASE-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Exercise multi-POS negative stock, credit reservations, frozen payment attempts, partial acknowledgements, cross-business receiving, return/remittance retries, corrupt queues and same-boot expiry/reboot. Compare durable business effects once.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/release-acceptance.md [planned]
- docs/task-results/RELEASE-05.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No deleting data to obtain green results, relaxed idempotency or treating current cache as fresh authorization.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/release-acceptance.md

Manual checks / observable acceptance:
Disconnect/restart/reconnect devices and reproduce every pending/conflict/review recovery path.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-05.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-06"></a>

### RELEASE-06 — Run full harness and matching client builds

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** acceptance · **Dependencies:** RELEASE-04, RELEASE-05

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RELEASE-06 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-06: Run full harness and matching client builds.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RELEASE-04, RELEASE-05. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Use pinned toolchain to run full harness, Firebase acceptance and explicit Development client builds; record exact results and distinguish build-only/setup-incomplete from hosted acceptance. Repair only findings assigned to feature owners.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/release-acceptance.md [planned]
- docs/task-results/RELEASE-06.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No skipped gate marked pass, blanket formatting unrelated work or compiling with fake operational URL.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/release-acceptance.md
bash tool/verify_harness.sh
bash tool/verify_firebase.sh
bash tool/build_client.sh pos dev apk-debug /absolute/path/client.dev.json
bash tool/build_client.sh admin dev apk-debug /absolute/path/client.dev.json
bash tool/build_client.sh admin dev web /absolute/path/client.dev.json
bash tool/build_client.sh driver dev apk-debug /absolute/path/client.dev.json

Manual checks / observable acceptance:
Run the commands in this card, verify all clients analyze/build cleanly and capture remaining external failures.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-06.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-07"></a>

### RELEASE-07 — Accept all actor workflows on actual devices

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** acceptance · **Dependencies:** RELEASE-06, RECOVERY-03

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RELEASE-07 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-07: Accept all actor workflows on actual devices.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RELEASE-06, RECOVERY-03. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
User manually rehearses Owner/Operations/rider/store/cashier flows with real Development identities and backend, narrow phone/tablet/wide Admin, keyboard, text scaling, camera/GPS and printer. Record observed evidence per feature.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/release-acceptance.md [planned]
- docs/task-results/RELEASE-07.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No fabricated location/sales, simulated printer accepted as hardware, production pilot or claiming all-device acceptance from screenshots.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/release-acceptance.md

Manual checks / observable acceptance:
Run a store-confirmed order through delivery/receipt/remittance plus retail cash/QR/credit/refund flows and recovery.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-07.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-08"></a>

### RELEASE-08 — Measure free-tier capacity and query indexes

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RELEASE-06

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-08 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-08: Measure free-tier capacity and query indexes.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RELEASE-06. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Measure realistic reads/writes/storage/index/backlog and foreground GPS/report costs against approved budgets; validate pagination, quota recovery and representative load in Development. Missing evidence blocks hosted readiness.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/engineering/FREE_CAPACITY_PROFILE.json [existing]
- firebase/firestore.indexes.json [existing]
- firebase/functions/src/https/capacity.ts [existing]
- firebase/functions/test/tasks/release_08.test.ts [planned]
- docs/task-results/RELEASE-08.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No quota assumptions from tiny fixture, paid fallback, second cloud database or unbounded query to simplify reporting.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/release_08.test.ts
git diff --check -- docs/engineering/FREE_CAPACITY_PROFILE.json firebase/firestore.indexes.json firebase/functions/src/https/capacity.ts
npm --prefix firebase/functions run check:capacity

Manual checks / observable acceptance:
Record 1-5-store workload accounting, index readiness and quota-exhaustion preservation of local work.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-08.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-09"></a>

### RELEASE-09 — Prepare and verify signed production artifacts

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** RELEASE-07, RELEASE-08

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RELEASE-09 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-09: Prepare and verify signed production artifacts.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RELEASE-07, RELEASE-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Validate explicit prod environment, release signing and fingerprints/App Check/Google auth with owner-controlled secrets outside repo; build compatible update artifacts preserving app data. Prepare installation/rollback evidence.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- apps/pos/android/app/build.gradle.kts [existing]
- apps/admin/android/app/build.gradle.kts [existing]
- apps/driver/android/app/build.gradle.kts [existing]
- docs/engineering/CLIENT_BUILD_SETTINGS.md [existing]
- docs/task-results/RELEASE-09.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No credentials in build flags/repo, changing application IDs to dodge update failure or installation/publishing without release authorization.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- apps/pos/android/app/build.gradle.kts apps/admin/android/app/build.gradle.kts apps/driver/android/app/build.gradle.kts docs/engineering/CLIENT_BUILD_SETTINGS.md

Manual checks / observable acceptance:
Build matching-signed artifacts and rehearse non-destructive update/rollback on approved test devices.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-09.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-10"></a>

### RELEASE-10 — Correct operator and disaster-recovery runbooks

**Model:** `gpt-6-luna` · **Reasoning:** `high` · **Kind:** implementation · **Dependencies:** RELEASE-07, RELEASE-08, RECOVERY-08

```bash
codex -m gpt-6-luna -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-10 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-10: Correct operator and disaster-recovery runbooks.
Use model gpt-6-luna with reasoning high; select it before starting.
Dependencies: RELEASE-07, RELEASE-08, RECOVERY-08. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Rewrite obsolete account, crypto, POS warehouse, receipt/printing and deployment claims from verified current behavior and canonical architecture. Include company/store roles, real settings/build commands, restore and cash-remittance procedures.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/engineering/OPERATOR_RUNBOOK.md [existing]
- docs/engineering/DISASTER_RECOVERY_RUNBOOK.md [existing]
- docs/task-results/RELEASE-10.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
Documentation only; no unsupported printer transports, 100-percent offline claim for privileged actions, legal certification or invented credential policies.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/engineering/OPERATOR_RUNBOOK.md docs/engineering/DISASTER_RECOVERY_RUNBOOK.md

Manual checks / observable acceptance:
A new operator follows login, checkout, order/dispatch, receiving, remittance and lost-device recovery using the documents.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-10.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-11"></a>

### RELEASE-11 — Prepare controlled deployment and rollback

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** RELEASE-09, RELEASE-10

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RELEASE-11 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-11: Prepare controlled deployment and rollback.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RELEASE-09, RELEASE-10. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Produce exact reviewed Development/Production hosting/API/App Check/index/secret checklist with free-runtime evidence, release approval gate, cutover backup and rollback steps. Publish only with explicit authorization in that execution session.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/task-contracts/deployment-checklist.md [planned]
- firebase/firebase.json [existing]
- docs/task-results/RELEASE-11.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No implied production permission, automatic paid fallback, real-world pilot before all gates or logging private credentials.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Verification commands (from repository root):
git diff --check -- docs/task-contracts/deployment-checklist.md firebase/firebase.json

Manual checks / observable acceptance:
Rehearse approved Development deployment, verify health/origin/app restrictions and restore the previous revision.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-11.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-12"></a>

### RELEASE-12 — Verify monitoring and recovery readiness

**Model:** `gpt-6.1-sol` · **Reasoning:** `medium` · **Kind:** implementation · **Dependencies:** RELEASE-11

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="medium"' 'Read AGENTS.md and execute only RELEASE-12 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-12: Verify monitoring and recovery readiness.
Use model gpt-6.1-sol with reasoning medium; select it before starting.
Dependencies: RELEASE-11. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md.

Goal and acceptance:
Verify safe operational logs, error/blocked-work visibility, quota indicators, incident ownership and real restore/rollback rehearsal; document alert thresholds from measured capacity. Record production readiness only when all evidence and explicit approval exist.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- docs/engineering/OPERATOR_RUNBOOK.md [existing]
- firebase/functions/src/https/server.ts [existing]
- firebase/functions/test/tasks/release_12.test.ts [planned]
- docs/task-results/RELEASE-12.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No paid monitoring service, raw customer/PIN/token logs, SLA guarantee or production-ready claim with blocked external gates.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI boundary: this card adds no visible screen; document or preserve its required states.

Focused testing: create/reuse the declared fast test for meaningful authorization,
financial or replay/durability boundaries relevant to this change. Cover a valid
case, a denial/conflict and retry/failure behavior; do not mirror implementation.
Keep full emulator, device and heavy UI suites for RELEASE acceptance.

Verification commands (from repository root):
npm --prefix firebase/functions run build
npm --prefix firebase/functions test -- --run test/tasks/release_12.test.ts
git diff --check -- docs/engineering/OPERATOR_RUNBOOK.md firebase/functions/src/https/server.ts

Manual checks / observable acceptance:
Trigger a safe Development failure, locate actionable evidence, restore/rollback and verify preserved pending finance.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-12.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

<a id="release-90"></a>

### RELEASE-90 — Release integration, review and usability acceptance

**Model:** `gpt-6.1-sol` · **Reasoning:** `high` · **Kind:** integration · **Dependencies:** RELEASE-01, RELEASE-02, RELEASE-03, RELEASE-04, RELEASE-05, RELEASE-06, RELEASE-07, RELEASE-08, RELEASE-09, RELEASE-10, RELEASE-11, RELEASE-12

```bash
codex -m gpt-6.1-sol -c 'model_reasoning_effort="high"' 'Read AGENTS.md and execute only RELEASE-90 in SARI_SUPPLY_TASKS.md. Read its copyable task and integrated prerequisite handoffs; do not read the entire guide.'
```

**Copyable task:**

```text
Implement only RELEASE-90: Release integration, review and usability acceptance.
Use model gpt-6.1-sol with reasoning high; select it before starting.
Dependencies: RELEASE-01, RELEASE-02, RELEASE-03, RELEASE-04, RELEASE-05, RELEASE-06, RELEASE-07, RELEASE-08, RELEASE-09, RELEASE-10, RELEASE-11, RELEASE-12. Verify their reviewed handoffs are integrated first.
Read: AGENTS.md; docs/architecture/SYSTEM_ARCHITECTURE.md; relevant docs/engineering/CURRENT_STATE.md entries; allowed current source files and direct prerequisite handoffs. Published contract: docs/task-contracts/release-acceptance.md. Read design.md before changing UI/copy.

Goal and acceptance:
Review all RELEASE task diffs and handoffs as a separate reviewer; integrate only declared route/export wiring, check exact role/data/UX contracts and repair findings through the original task scope. Run scoped analysis and the milestone manual script; update evidence and checklist only after integration.

Allowed writes (existing = inspect/reuse; planned = proposed creation after contract verification):
- firebase/functions/src/https/commands.ts [existing]
- firebase/functions/src/index.ts [existing]
- packages/sarisupply_auth/lib/sarisupply_auth.dart [existing]
- packages/sarisupply_models/lib/sarisupply_models.dart [existing]
- packages/sarisupply_firebase/lib/sarisupply_firebase.dart [existing]
- apps/pos/lib/app/pos_app_gate.dart [existing]
- apps/admin/lib/app/admin_app_gate.dart [existing]
- apps/driver/lib/app/driver_app_gate.dart [existing]
- docs/task-results/RELEASE-90.md [planned]
No other writes. If a necessary existing handler/test/migration lies elsewhere,
record the finding and obtain a coordinator scope amendment before editing it.

Limitations and exclusions:
No unrelated refactor, heavier per-screen pump matrices, skipped gate marked pass, blanket production deployment or architecture changes.
Preserve data, immutable financial facts, pending work and operation IDs.
Keep authoritative business/role/scope checks and offline replay contracts.
No unrelated refactor, paid fallback, fabricated success or secret exposure.
Do not execute later tasks or silently change model, provider or architecture.

UI/UX acceptance:
Follow design.md and existing shared Warm Utility components/tokens.
Keep this feature in its actor's app with visible business/scope context.
Handle loading/empty/denied/pending/offline/error/retry/success as applicable.
Preserve valid input; make financial/destructive actions explicit.
Manually check 320/390 px, 200% text, 48 px targets, keyboard/back/scroll;
check 600/1024 px where applicable. No unrelated visual redesign.

Verification commands (from repository root):
(cd apps/admin && flutter analyze)
(cd apps/driver && flutter analyze)
(cd apps/pos && flutter analyze)
(cd packages/sarisupply_auth && flutter analyze)
(cd packages/sarisupply_firebase && flutter analyze)
(cd packages/sarisupply_models && flutter analyze)
npm --prefix firebase/functions run build
git diff --check -- firebase/functions/src/https/commands.ts firebase/functions/src/index.ts packages/sarisupply_auth/lib/sarisupply_auth.dart packages/sarisupply_models/lib/sarisupply_models.dart packages/sarisupply_firebase/lib/sarisupply_firebase.dart apps/pos/lib/app/pos_app_gate.dart apps/admin/lib/app/admin_app_gate.dart apps/driver/lib/app/driver_app_gate.dart

Manual checks / observable acceptance:
Walk the completed milestone with real Development roles when available; record each missing external acceptance gate explicitly.
Report unavailable identities/backend/hardware/configuration as pending gates.

Handoff:
Write docs/task-results/RELEASE-90.md with reused/replaced behavior, touched files, contract assumptions,
exact commands/results, manual evidence, unresolved gates and next action.
Do not edit the coordinator checklist. Completion requires scoped verification
and independent review; production acceptance requires all external gates.
```

## Final completion rule

RELEASE-90 reviews the whole integrated system and evidence, not just the release documents. Every required feature must be usable by its canonical actor, data-preserving migration rehearsed, security and offline acceptance passed, actual hardware/device workflows observed, measured free-tier capacity acceptable, recovery tested and release approval recorded. Otherwise keep the precise unresolved gate visible. A completed roadmap file, compile pass or signed APK is not proof of production readiness.
