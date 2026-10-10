# SariSupply Current State

**Last reviewed:** 2026-10-07

This document describes the repository implementation; deployment and live-device validation are recorded separately.

## Checkout cached product visibility — 2026-10-07

The connected Development POS had 62 active cached products, but checkout hid
catalog rows whenever search was blank. Checkout now shows the existing local
catalog page while the cart is empty and during explicit search; an active cart
retains its focused view. No inventory, authorization, receipt or outbox changes.
The shared design contract reflects this correction.

The new focused check reproduced the missing rows before the fix, then passed
product selection, cart addition and searching with a cart. All 14 checkout screen
and controller checks pass. Full POS analysis reports zero issues; formatting,
architecture boundaries and the sanctioned Development debug APK build pass.
Package, signing certificate and version compatibility were checked before the
successful in-place update on vk55gmzh6tgabqey. First-install time was preserved.
The app reopened and the device reached the signed-in scanner; final checkout
product-list visual acceptance remains manual. Full harness/emulator tests remain
deferred under presentation build mode.

## Barcode scanner presentation refinement — 2026-10-07

Removed the instructional paragraph and redundant item heading. The scanner
prioritizes a larger rounded camera area with aiming guidance and compact
Ready/Updating status. The last product has a bordered card with exact unit
price and quantity controls. Added to cart, Scan again, Enter barcode and Done
with total keep routine copy short; error/access recovery remains explicit.
Continuous scanning, duplicate suppression and local-save confirmation are intact.

Full POS analysis, architecture boundaries, 13 focused scanner/checkout checks
and the sanctioned Development debug APK build passed. Phone/large-text layouts
and camera/manual fallback were checked. The user authorized immediate installation;
package/signing/version compatibility passed and the update installed in place on
vk55gmzh6tgabqey, retaining the original first-install timestamp. The app reopened
to cashier sign-in. Physical-camera acceptance awaits cashier login; full
harness/emulator testing remains deferred.

## POS checkout continuous scanning — 2026-10-07

Checkout now keeps the scanner open across item additions and barcode misses.
The scanner shows the last added product, exact selling unit/price, quantity
controls and total. Held duplicate barcodes add once; + and Scan same item again
allow deliberate repeats. Numeric quantity entry works from scanner and cart.
Search/scanning and payment remain reachable around the scrolling cart; catalog
results appear during explicit search. Manual barcode entry expands on camera
failure. Scans pause during edits/saves, covered routes and inactive lifecycle;
access is revalidated before scans. Addition confirmation follows durable saving.
Existing authorization, quoted-price review, receipts and outboxes are preserved.

Full POS analysis has zero issues. All 22 focused scanner, checkout, controller
and payment checks passed, covering duplicate handling, direct quantity entry,
barcode misses, durable restart, authorization denial, cash/QR and price review.
Architecture boundaries and the sanctioned Development debug APK build passed.
Full harness/emulator acceptance remains deferred under presentation build mode;
physical barcode-camera usability still requires hands-on verification.
The Development APK was installed in place on vk55gmzh6tgabqey after package,
version and signing compatibility checks. The original installation timestamp
was retained. The app process started and reached Google account selection;
store workspace loading awaits user sign-in and is not verified by installation.

## Driver presentation refinement — 2026-10-07

Driver now prioritizes rider workspace selection, the next assigned stop and the
current delivery stage. Signed-in workspace selection uses compact branding;
company management roles are secondary. Route progress says “stops recorded,”
with explicit partial-delivery and pending-sync labels. Primary actions use ink
on orange for readable contrast. The saved delivery steps, money calculations,
authorization, offline access and durable proof/draft behavior are unchanged.

Driver/company-package analysis and nine focused phone/access/route checks pass.
A matching Development APK was installed in place; cold launch and existing
company/rider access loaded. No data reset was used. Live delivery flow acceptance
remains a manual check.
See [design critique and verification](../task-results/DRIVER-DESIGN-2026-10-07.md).
Full-platform and manual delivery acceptance remain separate.

## Development presentation inventory — 2026-10-07

Development Firebase now contains 62 matching active products in Beta Store /
Main branch and SariSupply warehouse Robert: 50 grocery demo items, including 20
new groceries, plus the 12 existing test items. Both catalogs have matching base
units, primary numeric demo barcodes and public photo links, with explicit 1:1
store/company product mappings. The 113 unit barcodes have valid EAN-13 checksums;
they are internal presentation numbers, not manufacturer GTINs. Photos are
representative category photographs; existing managed store photos are preserved.

The trusted Development-only seed utility checks current Owner authority and
uses the existing catalog, opening-stock, warehouse receipt and mapping services.
It added 32 missing retail stock records and 58 missing warehouse stock records;
all 30 prior retail balances and four prior warehouse balances/revisions remain
unchanged. Private backups and exact replay payloads are outside the repository.
This seed changed no roles, security rules, API deployment or installed application.

Live cloud comparisons passed. POS change feeds contain all 62 new catalog
changes and 32 new stock changes without sequence gaps. Replaying a seeded item
left stock, revisions and feed cursors unchanged. Server TypeScript build, script
syntax and photo-link validation passed. Phone display acceptance remains a
manual Sync/Refresh check; full harness/emulators remain deferred. See
[seed evidence and grocery barcode list](../task-results/PRESENTATION-DATA-2026-10-07.md).

## POS Reports & Archival UI — 2026-10-07

Audited the phone’s Reports screen and all four tab layouts. Sales now emphasizes
net sales, groups adjustments/payments/cash drawer figures, and places previews
and clipboard exports near the summary. Stock separates retail value, unavailable
cost/profit, stock status, expandable movements and product details. Short Sales,
Stock, Backup and Printer navigation labels retain original tab indices and keep
branch/device scope visible. Supporting rows/actions stack at enlarged text.

Backup presents Create, Copy and Verify steps with plain password guidance,
in-progress controls, guarded asynchronous UI updates and explicit temporary-copy
semantics. Archive encryption, verification, retention and recovery paths are
unchanged. Verification reports actual password/integrity checks without a
misleading legacy sales count. Printer uses vertical paper-width choices and an
honest preview-only explanation. Receipt previews use a full phone page or bounded
wide dialog with scrollable receipt columns and one copy action; daily report
previews explicitly identify placeholder shift/count metadata. Sales/stock
calculations, server roles, local records and outboxes were not changed.

Focused phone checks cover all four tabs, scroll/return navigation, paper-width
selection, test-receipt preview and dismissal. The live phone capture caught
a scroll/expansion state collision that initial layout-only checks missed; a
regression reproduced the double-to-bool cast, and separate section storage keys
corrected it. Material surfaces were also corrected for radio/expansion interaction
rendering. Both corrections passed normal and enlarged-text checks. Formatting, POS analysis (zero issues),
architecture boundaries and scoped whitespace checks passed. The sanctioned Development debug APK build passed. Matching package, signing
certificate and version code were verified before an in-place update on
vk55gmzh6tgabqey. The original first-install timestamp was preserved and the
POS process reopened. The corrective build loaded the authenticated Main branch
Overview with PHP 362.00 and two transactions. The phone remains on Overview;
final report-tab visual acceptance is pending because automated taps are blocked.
Full harness/emulator suites remain deferred
under the presentation build workflow. Live backup/copy/verification and physical
printer capabilities are not established by this layout check.

## Store overview UI audit — 2026-10-07

Captured the connected phone’s POS Store overview. The sales amount split across
lines, repeated headings and a large scope disclaimer consumed the first screen,
and low-stock rows did not distinguish unavailable products visually.

The overview now uses compact store/branch context, a full-width net-sales card
with transaction count and a secondary Sales report action, an expandable scope
notice, and a primary Open inventory action. Stock rows separate product/SKU from
quantity and explicit Out of stock / Low stock labels. Narrow or enlarged-text
layouts stack groups; long monetary values scroll horizontally without shrinking
text or breaking their digits. Existing local reads, summary calculations,
branch selection, permissions and inventory/report routes are unchanged.

Formatting, POS analysis (zero issues), architecture boundaries, whitespace checks
and the sanctioned Development debug APK build passed. Matching package,
signing certificate and version code were verified before a successful in-place
update on vk55gmzh6tgabqey; its original first-install timestamp was preserved.
The app reopened through Google account selection and then displayed authenticated
Daily Sales reports with PHP 362.00 net sales and two transactions. Dashboard
visual acceptance is pending: the phone remains in Reports and blocks automated
taps. Screenshots are held under /tmp/sarisupply-dashboard-ui.
Automated test suites, full harness and emulator matrices were deferred under
the presentation build workflow; no business operation was performed.

## Company Owner store application review — 2026-10-07

Admin's More → Company page now includes an Applications tab for Company
Owners. It lists pending store applications through a trusted backend command;
the backend checks the current Company Owner membership for both list and
review. Approval rechecks that role in the idempotent transaction that creates
the store, first branch, and applicant's Owner membership. Rejection requires
notes and records the reviewer and company in the application audit event.
Warehouse Operations and Store Owner workspaces do not receive this screen. The
separate Platform Admin review path remains available.

The merchant-application query index is added to source configuration but has
not been deployed. Admin and shared-package Dart analysis and the Firebase
Functions TypeScript build pass. Emulator and live authenticated acceptance
were not run for this change; public production availability is not established.

## Replenishment and ordering — 2026-10-07

Local source implements persistent catalog/cart ordering, cached bounded reads,
branch delivery defaults, paginated low-stock suggestions with confirmed unit
mappings, and separate warehouse sourcing requests. Cart edits make zero catalog
reads in focused checks. Scoped analysis, TypeScript build, architecture checks
and 59 focused checks pass. POS/Admin Development APKs and Admin web compile.
Development backend revision `c4p3q7kqhh2n` is deployed and verified on the
existing Development hostname after token refresh. Live endpoint/authentication
smoke checks pass. Matching POS/Admin release APKs are installed and native
startup checks pass. Authenticated manual acceptance and measured phone latency
remain pending.

An incorrectly configured Flutter Drive benchmark uninstalled the normal
Development POS package during cleanup and removed its local data directory.
The **03:17 backup and pre-benchmark release APK have now been restored**;
Android reported successful reinstallation. Later unsynced changes cannot be
confirmed recovered, and secure credentials may require fresh sign-in/device
registration. Read-only canonical cloud evidence is preserved privately.
Admin/Driver were not uninstalled. See
[implementation, verification and incident details](../task-results/REORDER-2026-10-07.md).

## Admin QR confirmation and order visibility — 2026-10-07

Company order details offer QR confirmation only while the existing unpaid
balance is positive. Excessive QR amounts now show a specific remaining-balance
message instead of the generic unavailable-action message. Read-only Development
inspection found the reported order already packed, with PHP 5.00 order value
and PHP 5.00 confirmed QR payment; its next stage is delivery assignment.

The redesigned Orders tab row no longer stretches against an unbounded vertical
constraint inside its horizontal scroll view. This corrects the blank Orders
page and restores access to Awaiting, Accepted, Ready and Completed queues.
The packed order belongs in Ready; no historical order or payment was changed.

The initial device update mistakenly installed an old unflavored `app-debug.apk`
artifact dated September 28. It was replaced with a newly built
`app-dev-release.apk`, using explicit Development flavor, environment and API
origin. The signing certificate matches the previous Admin APK. The installed
APK hash matches the new release artifact; app data and its original installation
timestamp were preserved. The final Admin update left the user's POS app open.
Scoped company analysis, all 11 existing order-queue checks and all four focused
company fulfillment checks pass. The added QR check covers partial/full amounts,
idempotent replay and rejection of an extra payment without another event or
revision change. The Development release build passes. The user confirmed tabs
and order rows appear; device capture shows one Awaiting order and two Ready
orders. Live new-order acceptance and QR payment remain user manual checks.
Full harness/emulator verification remains deferred.

## Performance delivery — 2026-10-07

Company operations now cache scoped datasets, share in-flight reads, cap reads at
three, lazily load sections and retain visible rows during refresh. POS management
retains section pages. Company pickers reuse loaded pages and debounce local
SQLite search. Relevant saves invalidate affected loaded pages; company stock
uses product stock projections. Driver proof saves commit locally before eligible
background upload, while pending run projections remain visible and the existing
seven-day same-boot authority restriction remains unchanged. Definitive denial
clears display caches without discarding durable drafts/outboxes.

Backend related-document reads are batched and authorization snapshots are reused
only within one transaction attempt. No schema/dependency changes. Physical-phone
profile benchmarks over 20 fixture repetitions measured warm-navigation p95
240.63 → 20.25 ms and 20 → 0 extra reads; local search p95 14.16 ms and atomic
local commit p95 at most 51.81 ms. These component measurements do not establish
live server or full authenticated-flow performance. Scoped analysis, focused
controller/authorization/durability checks and architecture boundaries pass.
Admin/POS/Driver Development release APKs and Admin web compile. Matching-signature
Android updates are installed with original first-install timestamps retained and
no app data cleared; native startup smoke checks pass. Backend changes remain
local; authenticated real user flow acceptance remains pending.
See [scope, samples, builds and limits](../task-results/PERFORMANCE-2026-10-07.md).

## Canonical architecture alignment — 2026-10-06

The user approved and adopted [SYSTEM_ARCHITECTURE.md](../architecture/SYSTEM_ARCHITECTURE.md)
as the business and system architecture contract. It establishes one supplying
company serving independent store businesses, company-owned warehouses and riders,
scoped warehouse operations, Store Owner-confirmed purchasing, and explicitly
store-authorized replenishment summaries. Platform administration remains distinct
from company operations. `AGENTS.md` and the engineering entry points now require
reading this contract and separate requirement precedence from implementation evidence.

This adoption changes documentation only. Legacy restocking/packing still uses
same-merchant branch destinations; dispatch remains under merchant Owner authority
in POS; legacy rider enrollment still uses account identifiers. Legacy
Platform Admin retail/procurement reads are now denied. Additive company workspace,
role and invitation support is described below; company-to-store orders, consent
enforcement and separate receiving/ledger reconciliation remain unimplemented.
Existing historical phase entries below do not imply these corrections are implemented.

## Presentation build mode and company authorization workspace — 2026-10-06

The user replaced per-card execution with reuse-first building across all three
apps, authorization/ownership first, light verification and user-led manual
testing. AUTH-01 remains the reviewed reference; contract version 1 is used for
the additive company workspace API. No company identity or data is auto-promoted.

The additive `authorizationVersion: 1` workspace API now discovers verified
company Owner, Warehouse Operations and Rider contexts, and checks explicit role
grants, current membership, revisions and company warehouse ownership on each
operation. Admin has a company workspace for warehouse setup, invitations and
staff-role management; Driver can review/accept invitations and see an assigned
Rider context. Platform administration remains separate and limited to onboarding.
Malformed store Owner scope fails closed. Trusted
`firebase/functions/src/company/provision-owner.ts` tooling establishes a verified
Google Company Owner with a role grant and discovery reference, transactional
audit and stable operation ID. It refuses takeover, removed-access reactivation
and a second supplying company; it is never a client command. It has been built
and was run against the operator-selected verified Google identity in Development.

Company purchasing, receiving/ledger reconciliation and company dispatch are
still absent. Legacy POS dispatch remains merchant-Owner/branch scoped; Driver has
no company-assigned deliveries yet. No company identity or store data is promoted,
and existing store checkout, durable work and business IDs remain preserved.
The Development API now routes invitation-response repair revision `faksa9a9xy7m`,
which built successfully and was explicitly promoted on 2026-10-06. The stable
Development URL previously served the older revision after the new build finished.
Public smoke checks now return HTTP 405 (`POST required`) for GET on
`getAuthorizationWorkspaces`, and HTTP 401 (`Authentication required`) for an
unauthenticated POST. These checks establish command registration and the Auth
gate, not authenticated role access. Hosted startup initially failed because
Cloudinary uploads were enabled without available server settings; the Development
setting was restored to `CLOUDINARY_UPLOADS_ENABLED=false`. Photo uploads remain
disabled pending valid provider configuration. Company-owner provisioning passed
in Development; authenticated live role/App Check checks and user-led device acceptance remain
pending. No business data or credentials were migrated.

Presentation access follow-up: after first Google sign-in, the operator-selected
verified account was explicitly provisioned as Company Owner using the trusted
tool and stable operation ID. No account was inferred from platform roles.
Driver invitation discovery exposed a missing collection-group index on
`invitations.recipientEmail`. The additive single-field index is recorded in
`firebase/firestore.indexes.json`, deployed to Development, and its live query now
passes after backfill. Admin adds warehouse invitation acceptance and Refresh
access for an account awaiting a company role.

Owner invitation repair: `listCompanyInvitations` now includes `companyId` in
each row, as required by the shared client model. An existing pending Operations
invitation in Development confirmed that creation had succeeded but the next
owner-page refresh failed parsing, preventing further staff/Rider invitations.
The repair preserves that invitation and current Owner-only authorization.
Focused backend checks passed (19 tests), the architecture check passed, and a
read-only check against Development Firestore returned the corrected row. The
isolated backend built and was promoted to the existing Development URL; no APK
change is required. The whole working-tree build remains blocked by unrelated
TypeScript nullability errors in the in-progress company operations service;
those commands were excluded from this isolated repair deployment. Phone invite
and recipient-acceptance checks remain user-led; full harness/emulators remain
deferred under presentation build mode.

Admin dialog follow-up: the phone displayed Flutter's `_dependents.isEmpty`
assertion after closing a company form. Focused tests reproduced premature
`TextEditingController` disposal in staff invitations, warehouse setup, and
Payment instructions. All three forms now wait for their dialog route to finish
removing its fields before disposing controllers. Three regression checks, Admin
analysis and the architecture check passed. The current-source Development APK
built and installed with `adb install --no-streaming -r`, after a private Admin
data backup. On-device navigation confirms Orders, Stock, Deliveries and More;
the previous one-page layout came from the earlier isolated build and is gone.
The owner page shows pending Operations and Rider invitations. Phone input
injection is disabled, so manual dialog close/submit and recipient acceptance
remain pending; no invitation was created or revoked during this verification.

The observed Driver delivery error was a local SQLite foreign-key failure when
assigned item snapshots referenced products absent from the Rider's retail
catalog cache. Inventory schema v11 retains the delivery-stop reference and
copies existing item rows while removing the unrelated product-catalog reference.
Focused tests passed for uncached assigned products and v10 upgrade preservation
of delivered/returned quantities, proof cash and pending operations (2 tests).
No local database reset is required. Company dispatch remains absent.

Verification: backend TypeScript build and focused authorization/command checks
passed (17 tests); scoped Dart analysis passed with no issues. Admin, Driver and
POS Development debug APK artifacts were produced. Full harness, emulators and
UI matrices are deferred as requested. No device is connected for hands-on
presentation acceptance.

## Product stage

SariSupply is in early production-foundation development. The approved direction is a Flutter-only client architecture with POS, Driver, and Admin applications, shared Dart/Flutter packages, Firebase cloud services, and a SQLite catalog/stock ledger and outbox foundation.

## Mobile brand UI refactor — 2026-10-06

The operator selected the supplied SariSupply Design System v1 board as the
visual source. POS, Admin, and Driver now use its paper backgrounds, white
surfaces, orange actions, ink typography, supplied SVG identity and navigation
icons, and shared spacing/radius tokens. Instrument Sans and the approved Inter
fallback are bundled locally; the fallback supplies the peso glyph in price
labels. Android launcher icons use the approved reverse symbol.

Admin has labeled Applications/Purchasing/Reports navigation with lazily opened
workspaces, retained search state, and Android Back recovery to Applications.
POS toolbars have fewer competing actions, scan uses a secondary treatment,
and inventory creation remains visible with its branch context. Report metrics
use neutral surfaces and larger tabular values. Driver status contrast, route
metadata wrapping, and narrow-phone delivery quantity controls were repaired.

Focused checks passed for shared branding/theme, Admin review states and
navigation retention, POS checkout with the keyboard, reports at 320px/200%
text, and representative screen snapshots. Formatting, affected-app analysis,
and architecture checks passed. The full harness is deferred under the
build-focused instructions. Phone installation and live presentation acceptance
are recorded separately; these checks do not establish full backend readiness.
See [implementation scope](../superpowers/plans/2026-10-06-brand-ui.md).

## Owner overview and management navigation — 2026-10-06

Store Owners now land on an Overview. Phone navigation keeps Overview,
Branches, Team, and Devices visible; Team exposes Cashiers, Managers, and
Invitations as role-filtered subtabs. Wide screens retain side navigation.
Overview shows today's local net sales and transaction count, the selected
branch's products at or below the ten-unit restock threshold, and direct
Sales report and Products & inventory actions. It states that sales are from
this POS device and may omit other devices or unsynced activity. The existing
authorization, management repositories, PIN controls, inventory ledger, and
report calculations remain the data and mutation path.

The owner-navigation test, management workflow tests, 320px/200% scaling check,
management overview screenshot, POS analysis, and architecture check pass. A
Development POS APK including this change is built. USB debugging has been
authorized; phone reinstallation is pending because the phone is currently
disconnected from ADB. The installed POS APK still has the previous management
navigation. Live Owner workflows still need hands-on
checkout and branch-stock acceptance. See [scope and invariants](../superpowers/plans/2026-10-06-owner-mobile-overview.md).

Development APKs for POS, Admin, and Driver are installed on the connected
phone using `adb install -r`, preserving app data. POS and Admin opened to their
live store-management/review screens; the POS process log contained no fatal
exception, unhandled Flutter exception, or App Check debug exchange failure
during launch. Driver's existing workspace APK included the current app and
design-system inputs. Hands-on checkout, stock change, and full backend workflow
acceptance remain pending.

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

## Foreground driver location sharing — 2026-10-06

- Driver can start/stop sharing GPS for an assigned dispatched/in-transit run, or update now. Capture/upload is immediate and repeats every 30 seconds while foregrounded. Backgrounding pauses sharing; return resumes only the opted-in session; restart requires starting again. Permission and GPS recovery states are explicit.
- POS Owner Dispatch provides a location card for an active route: coordinates, reported accuracy, capture/receipt times, sharing state, assigned stops, refresh and external Maps. Samples older than 90 seconds are last known. The dispatch/location lists share the page scroll area and dispatch has explicit refresh.
- Trusted `manageDeliveries` actions `updateDriverLocation`, `pauseDriverLocation`, and `readDriverLocation` enforce current driver/run/warehouse/merchant authority. Only owners read snapshots. One latest snapshot per run replaces prior samples; stale samples and out-of-order uploads are rejected. Firestore client rules remain deny-by-default.
- GPS samples never enter the durable delivery outbox. Failed uploads retain the last displayed success; delivery proofs, stock, cash and local business data are unaffected.
- Foreground-only scope: no tracking during external Maps, screen lock or other apps; no embedded map, ETA, optimization or travel history. One-phone presentation demonstrates Driver capture followed by POS retrieval, not continuous movement across apps.
- Added `geolocator_android` only to Driver for GPS/permission access and `url_launcher` to POS for external Maps. A 30-second schedule costs approximately 120 location writes per active driver/hour, plus pause writes. Normal update authorization reads five documents (merchant, driver, run, warehouse, previous snapshot); owner read costs eight reads, or seven when owner is also assigned driver. One continuously viewed route adds approximately 960 reads/hour; an active driver's samples add approximately 600 reads/hour, excluding retries and other application work. Free-tier operational capacity remains to be measured.
- Local evidence: eight controller tests, two phone-layout/stale-location tests, and ten delivery emulator checks passed. Whole-workspace static analysis, architecture check and backend compilation passed. Full harness and final hardware acceptance remain deferred under build-focused instructions.
- Development backend revision `3tjnmvj7yfvq` built successfully and was promoted to the existing Development URL; previous revision `42wrrxfpnyd4` remains available for rollback. Authenticated client acceptance and matching-signature APK installation are tracked separately below.

- Live Development acceptance: authenticated owner catalog/stock feeds each return all 30 presentation products, and the assigned Driver identity reads its workspace and one dispatched run. Query indexes are READY. One packed presentation manifest is available; no sale or GPS fix was fabricated. The device should refresh Driver assignments when reconnected.
- POS and Driver Development APKs rebuilt and installed as matching-signature updates; POS previously displayed Checkout with retained branch/access state, and Driver home was visually confirmed on-device. The Driver is now assigned to a dispatched presentation run. Both location permissions remain ungranted pending the driver’s choice; GPS upload and the POS location card still require a manual tap to grant permission and start sharing. Private POS/Driver data backups were saved before installation.
- Build dependency correction: Driver uses the Android Geolocator implementation directly. The cross-platform wrapper pulled Linux geolocation/package-info dependencies and a second Android compiler toolchain; removing those irrelevant platforms preserves foreground GPS behavior and avoids their downloads.

## Development presentation data — 2026-10-06

The active Development store (`beta-store`, branch `main-branch`) now has 30 sample retail products with base/pack prices and opening branch stock, three added demo suppliers, eight added demo customers with no phone numbers or credit allowances, and two completed sample purchase orders that received 50 units per product into warehouse inventory. It has one active authenticated Driver, one packed sample replenishment manifest, and one dispatched delivery run. Seed writes used the deployed trusted command API; deterministic `demo-*` IDs and presentation notes identify the fixtures. No sales, customer credit, or GPS coordinates were fabricated.

Development Firestore query indexes declared by the repository were deployed because the Driver route query was returning an internal error. The composite route indexes are READY; authenticated tests now read one driver workspace and the dispatched run. The phone disconnected before its final assignment refresh. Additional usable Drivers require additional Google-authenticated accounts; no placeholder identities were created.

## Cloudinary product photos (2026-10-06)

Local implementation adds Owner camera/gallery photo selection in POS, signed
Cloudinary upload and server verification through the existing Deno HTTPS gateway,
atomic managed-image attachment/removal in catalog saves, backward-compatible
image delta/SQLite serialization, public optimized catalog/checkout images,
bounded Android disk caching, free-usage/daily-upload safeguards and a retryable
operator cleanup command. No financial record schema or offline financial outbox
changes. Existing preset/custom HTTPS URLs remain supported.

Uploads default disabled. The selected SariSupply Cloudinary credentials are
validated and stored in the private local Development environment file outside
the repository. The operator configured the Deno Production runtime context for
the Development app; the secret remains masked and the upload flag is false.
Deployment of the Cloudinary-enabled backend, live upload/cross-device sync,
camera/permission and offline-device acceptance remain pending. See
[CLOUDINARY_PRODUCT_PHOTOS.md](CLOUDINARY_PRODUCT_PHOTOS.md) for private setup,
limits, acceptance and rollback. Heavy harness/emulator suites remain deferred.


Local Cloudinary verification: nine-package analysis clean, TypeScript build and
architecture check passed, 23 focused checks passed, and Android POS Development
APK compiled successfully. This does not establish hosted or real-device acceptance.


## Company ordering and dispatch — 2026-10-06

Presentation implementation reuses reviewed AUTH-01 authorization, trusted HTTPS
commands, retail catalog/stock feeds and existing role invitations. New company
records stay under `companies/{companyId}`; company stock never uses a retail
merchant as its owner. The shared `packages/sarisupply_company` feature serves
Admin company operations, POS Store Owner ordering and Driver assigned runs.

Implemented: company products with immutable SKU/base unit and revision-checked
prices; opening/incoming stock; reservation, picking, packing, shortage proposals
and store approval; ordered multi-stop dispatch; assigned Rider quantity/recipient
proof and cash collection; Store Owner receipt with explicit retail unit mapping;
warehouse return quarantine and manual QR/cash remittance reconciliation. Each
mutation rechecks current authority and uses an immutable operation receipt and
audit record. Duplicate proof/receipt operations cannot add stock or cash twice.
Zero receipt quantities create no empty stock-feed event. Receipt stock reaches
POS through its existing stock sync after leaving company orders.

Driver proof and run projections are stored atomically in separate company/user/role
SQLite storage. Pending and blocked evidence survives restart; offline recording
requires verified same-boot authority within seven days, and reconnect rechecks
current assignment. Store receipt stays an offline draft until server acceptance.
Admin web uses scoped browser storage for drafts and operation IDs; Rider work
requires Android. Existing retail/legacy delivery records and outboxes remain.

Development backend revision `pwqma683s9v5` built and promoted at the existing
Development URL; rollback revision `wz78ghppq0ty` remains available.
Android Admin, POS and Driver Development APKs built and installed with
`adb install --no-streaming -r` on device `vk55gmzh6tgabqey`; no uninstall or
application-data clearing. Admin web compiled locally; web hosting was not updated.
On-device Admin navigation visibly contains Orders, Stock, Deliveries and More.
A subsequent device hierarchy showed the selected warehouse, a saved company
product and its available/reserved/in-transit/quarantine balances, with Receive
stock/Edit price actions; authenticated catalog display is observed. This does
not establish a complete order/delivery/receipt acceptance trace.

Verification: `npm run build`;
`npx vitest run test/company/operations.test.ts test/https/commands.test.ts test/common/authz.test.ts`
(20 passed); `flutter test test/company_work_store_test.dart` from inventory
(1 passed); scoped Dart analysis and `dart tool/check_architecture.dart` passed.
All three Android builds used `flutter build apk --debug --flavor dev
--dart-define=SARISUPPLY_ENV=dev
--dart-define=SARISUPPLY_API_URL=https://aracena18-sarisupply-dev-api.aracena18.deno.net`.
Admin additionally passed `flutter build web` with the same environment/API defines.
Hosted command GET returns 405 and Development-header unauthenticated POST returns
401; these establish route/authentication gates, not authenticated business-flow
acceptance. Source self-review and scoped diff whitespace verification completed.

Pending manual gates: real Store Owner order and retail product mapping; company
stock counts; invited Google-authenticated Warehouse Operations/Rider accounts;
partial delivery, reconnect, return discrepancy and actual money verification;
free-tier traffic capacity. Company delivery proof currently captures recipient
name/role and quantities, without a signature image. Existing legacy foreground
GPS remains available on its legacy flow; company runs do not yet expose live
location sharing. Warehouse and Rider selection reads are currently bounded to
100 records; larger organizations require pagination. One warehouse/shipment per
order; at most 20 lines/order and 20 stops/run. No upstream purchase orders,
automatic QR verification, live migration, paid fallback or production acceptance.
Heavy harness/emulator/UI matrices remain deferred under presentation build mode.

Manual starting point: Admin → More → add warehouse/invite staff; Admin → Stock →
add company product and receive opening stock; POS Owner → Inventory → Order from
SariSupply; Admin → Orders → accept/pick/pack; Deliveries → create/dispatch run;
Driver → record delivery; POS Owner → confirm actual receipt; Admin → receive
returns and record actual remittance.


## Checkout notice and stale-price recovery — 2026-10-06

POS no longer reports every failed cart addition as a cart-limit/price error.
Stale quotes offer the existing explicit Review prices flow in a transient popup;
quantity, barcode and scan notices dismiss instead of staying in the page.
Access denial and unresolved durable-save/sync states stay visible. Successful
cart edits and price approval clear old edit errors. Focused controller checks
cover persisted repeated additions, rejected changed quotes retaining original
quantities/prices, explicit price approval followed by successful addition, and
the 20-product cart boundary with existing quantity increments, and
the existing observed-denial authorization race (3 passed). No cart limits,
financial snapshots, live stock, receipts or pending operation IDs were altered.
The reported device failure was not captured during inspection; the phone was
in checkout and performing sales. A stale-price rejection was reproduced locally.
The user subsequently reported that clearing a full cart allowed purchasing,
consistent with the cart boundary. Checkout now shows product/line counts and
identifies that limit directly; it preserves the cart instead of clearing it.

Scoped checkout analysis and diff whitespace checks passed. Development POS APK
rebuilt and installed with `adb install --no-streaming -r` on the connected
phone; the app was reopened. Updated popup dismissal and cart count still require
the user's manual device check.


## Company order acceptance shortage — 2026-10-06

Read-only Development inspection found the submitted order requesting one unit
each of two company products whose selected warehouse stock was zero. The
server correctly prevented reservations exceeding available company stock.
The shared client previously hid that reason behind a generic failed-precondition
message. Known warehouse-shortage, stale-order revision and already-processed
order errors now display specific recovery instructions; retry classification
continues to use codes. No stock or order state was changed by inspection.
Receive actual warehouse stock or propose smaller quantities before acceptance.
Focused Dart analysis and whitespace checks passed; no automated tests added
for this message-only correction.

Admin Development APK rebuilt, installed as a preserving update and reopened
on the connected phone. Acceptance after receiving actual stock remains a user
manual gate.

## Rider delivery amount review — 2026-10-07

The legacy Driver stop completion screen displays each delivery manifest unit
amount, its delivered line amount, and the total value for delivered quantities.
The cash field shows that total as its maximum and validates before local save,
using the same manifest amounts as the existing local and trusted-server cash
checks. The legacy manifest still does not distinguish company purchase cost
from an agreed wholesale selling price; do not treat its amount as a new pricing
contract or add a separate delivery fee without an approved data source.

Driver Development analysis passed with no issues. The Development `devDebug`
APK built and was installed in-place with `adb install -r` on device
`vk55gmzh6tgabqey`, preserving the existing app installation and local data. It
was reopened and its process confirmed running. Rider quantity, return, amount
display and cash-limit checks remain for the user's manual phone test. Full
harness verification is deferred under the active presentation build workflow.


## Company Rider route presentation — 2026-10-07

Driver had separate presentation paths: legacy merchant assignments opened the
redesigned DriverHomeScreen, while company-invited riders opened the shared
CompanyOperationsScreen. Company riders now use the approved flat My Route layout:
route progress, a compact next stop with units and COD, two upcoming stops, a
collapsed completed row, and a sticky directions/proof CTA. The route name falls
back to ordered destination names because current run records do not carry a
route-name field. Directions and proof still use the existing callbacks, company
form, current authorization checks, scoped storage and durable outbox; no records
or roles were migrated. Pull-to-refresh, pagination, account/workspace controls,
and pending/error notices remain. GPS and signature capture are unsupported for
company runs. Admin and Store Owner layouts are unchanged.

Verification: formatting, Driver analysis and targeted analysis of the changed
company rider route pass. Whole-company-package analysis reports the pre-existing
flow-control-braces lint in order_shop_screen.dart, outside this change. The
Development debug APK was rebuilt and installed in-place on vk55gmzh6tgabqey;
package, version and signing certificate matched, and first-install time was
preserved. The account exposes a Rider workspace with one warehouse; its loaded
run is 1/1 complete, so the screen shows Finish route without upcoming stops.
Device input injection is restricted, leaving workspace entry for the user's tap.
Full harness/emulator matrices remain deferred under presentation build mode.

The sanctioned build_client.sh command built the Development debug APK with
client.dev.json. Installed package, version code and signing certificate matched;
adb install --no-streaming -r succeeded on vk55gmzh6tgabqey. Driver reopened and
its process was running. Device UI automation returned no root node, so visual
acceptance with the invited account and actual delivery submission remain for
the user's manual phone check. No uninstall or application-data clearing occurred.


## Item Requests blank page correction — 2026-10-07

ItemRequestsScreen nested a ListView inside SariSupplyPageContent's existing
SingleChildScrollView, producing “Vertical viewport was given unbounded height”
and preventing request, empty and error content from rendering. The screen now
uses a stretching Column inside the existing page scroll area. Request loading,
warehouse/store scope, response actions, pagination and server authorization
are unchanged. This shared correction applies to Admin and Store Owner entry.

Three focused widget checks reproduced the failure before the change and passed
afterward: populated phone content and scrolling, empty state, and failed-read
recovery with refresh. Admin and POS analysis, affected shared-source analysis,
formatting and architecture checks passed. The sanctioned Admin Development APK
build passed; matching package, version and signing certificate were verified
before adb install --no-streaming -r succeeded on vk55gmzh6tgabqey. Admin was
reopened without uninstall or app-data clearing. The POS APK was not rebuilt.
Live Item Requests navigation/data and response submission remain user manual
checks. Full harness/emulator matrices remain deferred under presentation mode.


## Store Owner Item Requests delivery and navigation correction — 2026-10-07

The reported blank page concerned Store Owner POS Inventory, not Admin. The
previous shared layout fix had only been delivered through an Admin APK update.
A focused POS test now verifies store request creation and refreshed history,
with warehouse response/close controls absent. POS analysis and the sanctioned
Development APK build passed. Package, signing certificate and version matched
the installation; adb install --no-streaming -r succeeded without clearing data.
POS was reopened; device automation returned no root node, so real sourcing
request submission remains a manual acceptance check.

Admin retains incoming sourcing requests as a distinct warehouse-scoped Orders
→ Requests action beside the order-status tabs. The loose link underneath the
Orders header was removed. Store Owner request placement remains Inventory →
Order from SariSupply → Request an item / View requests. No stock, membership,
backend permissions, request mutations or durable storage changed. Three existing
request UI checks, Admin analysis, affected shared-source analysis, formatting
and architecture checks passed. Admin Development APK also built and installed
as a compatible in-place update.
Full harness/emulator matrices remain deferred under presentation mode.


## Warehouse Stock blank header and owner controls — 2026-10-07

The redesigned Stock header stretched its horizontal filter Row vertically
inside an unbounded sliver, causing “BoxConstraints forces an infinite height.”
This prevented rendering the header and its existing owner product creation and
stock receipt controls. The header now uses natural filter heights, preserving
its Warm Utility layout. Company Owners see Add product; scoped operations see
Receive stock. Initial loading shows a labeled state and unavailable writes stay
disabled. Refresh stock is explicit. Existing server role checks, stock ledger,
product forms, warehouse filters and scoped page cache remain intact. No backend
query or network timeout was changed.

The original stretching layout reproduced failures in both new header checks;
the corrected sliver render/action and loading-state checks pass. Seven existing
controller checks also pass, covering warm-cache reuse, coalescing, page retention
and scope/late-response safety. Admin and affected shared-source analysis,
formatting, architecture checks and sanctioned Admin Development APK build passed.
Matching signing, package and version were verified before a successful preserving
adb install --no-streaming -r on vk55gmzh6tgabqey; Admin was reopened.
Live Stock navigation, actual item creation/stock receipt and end-to-end network
latency remain manual phone acceptance checks. The rendering failure explains
the blank page; a measured one-minute backend delay was not established.
Full harness/emulator suites remain deferred under presentation build mode.


## Warehouse product sheet UX review — 2026-10-07

Captured the user's open phone screen: Admin Stock with Another1's product-details
sheet. The audit found an undifferentiated stock text block, equally emphasized
receiving/edit/correction actions, a transit-write-off action at zero transit, and
an inactive barcode affordance in the background header.

The sheet now groups availability/status and reserved/transit/quarantine balances
with explicit units, SKU, wholesale price and warehouse context. Receive stock is
a reachable primary button; product edits are grouped and Stock corrections are
collapsed. Transit write-off appears only with nonzero transit and uses destructive
color. The Stock header prioritizes receiving, gives product creation a secondary
button and stacks controls on small screens/large text. Search uses a real clear
action instead of an inactive scanner. Existing action dispatch, role restrictions,
stock forms, server mutations, durable data and navigation remain intact.

Four focused UI checks passed, including the product sheet at 320 logical pixels
with doubled text. Admin and affected shared-source analysis, formatting, boundary
checks and sanctioned Development APK build passed. Signing/package/version were
verified before a successful in-place update on vk55gmzh6tgabqey. The original
phone capture is /tmp/sarisupply-current-screen.png. The updated capture was black
while Android reported mWakefulness=Dozing; final device visual review is pending
reopening the same sheet. Full harness/emulator suites are deferred
under presentation build mode.

### Warehouse Orders item workflow — 2026-10-07

Reviewed the connected phone’s Orders screen. Warehouse order details now group
items with line totals, display stage-specific fulfillment guidance and a single
primary action, separate QR verification from fulfillment, and retain proposed
items for store approval. Packing/proposal field labels identify each item and
unit. The queue reference uses one line; the full ID remains in details. Store
Owner ordering, trusted command payloads, stock reservation and payment ledger
rules are unchanged. Device flow acceptance remains manual; full harness deferred
in presentation build mode.

Verification: Admin analysis and affected shared Dart analysis pass with zero
issues; 13 focused Orders checks pass, including 320px / 200% text, lifecycle
actions and disabled cached orders. Architecture boundaries and dev debug APK
build pass. Installed in place after package/signing/version checks. A phone
screenshot confirms expanded Next step and item rows. Device review caught an
assertion in the nested selectable order-reference control; replaced it with
plain full-reference text and rebuilt/reinstalled. End-to-end order mutations
remain for manual verification. Repository-wide diff whitespace check reports
an existing unrelated trailing blank line in firebase/functions/deno.json.

### Warehouse Orders modal refinement — 2026-10-07

Following phone review, the warehouse order queue now keeps only store, total,
status, item count and time. Tapping a row opens a 92%-height modal with item
line totals, a short stage cue, pinned primary fulfillment action, and collapsed
delivery/payment details. Secondary order actions are under More. This removes
long inline copy from the scrolling Orders page. The Admin dev APK was built and
updated in place; order mutations remain server authorized. The updated modal
was opened and captured on the connected phone.

### Store Owner wholesale payment choice — 2026-10-07

Store Owner order review now requires an explicit Cash on delivery or QR choice.
QR is disabled until the supplier configures payment instructions; the order
stores a snapshot and stays pending until the supplier manually confirms actual
payment. The chosen method appears in order history and Admin details. Dispatch
carries the method and due amount to Driver; QR stops clearly say to collect no
cash, and the trusted proof operation rejects cash for QR orders. Older orders
without a method retain COD behavior. No payment gateway or automatic transfer
was added.

Formatting, Admin/POS/Driver analysis, shared company/model package analysis,
architecture checks and the Firebase Functions TypeScript build passed.
Automated test suites and manual order/payment acceptance were not run, so the
Development backend was not deployed. `FREE_BACKEND.md` identifies Deno Deploy
as the current HTTP runtime and makes publishing a separate operator action
after code/configuration review; Firebase Functions remain for emulator callables.
The changed trusted operation source is ready for that review. The deployed
Development API remains on its prior revision, so the new QR selection is not
live until a future Development deployment.


### POS Branches, Team and Devices UI — 2026-10-07

Reviewed the connected phone's Branches screen and the shared management layouts.
Added page headings, store context, primary/secondary action hierarchy, wrapping
Team tabs, search over loaded records, explicit status badges and branch access
counts. Pending invitations say Awaiting acceptance. Device IDs and activation/
revocation guidance remain visible. Forms explain branch scope and temporary PINs.
Inactive branches no longer expose an empty menu; destructive actions retain
confirmation and use distinct icon/color cues. Switching stores retains the
Branches or Devices list kind. No management command or server permission changed.

Verification: POS analysis passes with zero issues; nine focused management
checks pass, including denial, PIN privacy/confirmation, retry operation IDs,
search and store switching. Two temporary phone preview checks passed at
390px/100% and 320px/200%, covering all three pages and all Team tabs. Captured
fixture previews for visual review. Formatting, architecture boundaries and
scoped diff whitespace checks pass. Full harness/emulator matrices remain
deferred in presentation build mode. Development debug APK built through
tool/build_client.sh with the required public client settings, then installed
in place after package, signing and version checks. Original first-install time
is retained. After restart the signed-in store workspace loaded the supplier
catalog and saved device stock on the phone. Final native review of the three
management pages and manual mutation acceptance are pending; remote taps are
blocked by the phone.


### Store supplier order UI — 2026-10-07

Captured the connected phone's Company Orders list and New order catalog.
The list now prioritizes New order, with secondary sourcing requests, local
search and All / In progress / Completed filters. Each card identifies the order
by a short reference, status, total, branch, product count and date; full IDs
remain in expanded Delivery & payment. Revised orders show proposed line totals
and their total before approval. Receipt/cancellation retain existing policies.

The catalog gives identity/price more room above wrapping quantity controls,
explicit Add to order, selling units and line totals. A single warehouse is
compact context. Search has a clear action and catalog freshness is secondary.
Suggested reorder shows device stock, mapped selling quantities, Change match,
and already-added state. Review keeps one scroll area, quantity edits, delivery
and payment choice, with pinned total/Submit and Close review. Validation brings
the relevant details or payment control into view.

Verification: shared company, POS and Admin analysis pass with zero issues.
Six focused controller checks and three review-flow checks pass, including
serialized draft writes, catalog reuse, access invalidation, acknowledged cart
clearing, 390px/100% and 320px/200% text. Architecture boundaries pass.
Development APK built with the required public settings and installed in place
after package/signing/non-decreasing version checks. The final correction APK
was rebuilt and reinstalled successfully; native screen acceptance is pending. Full harness/emulator suites are
deferred in presentation mode. No backend or payment deployment was performed;
the prior documented live-backend limitation for explicit QR choice remains.

### Admin owner and warehouse UI refinement — 2026-10-07

Reviewed the connected phone's Admin Orders and Stock screens and the Company
administration source. Orders had a dead-end empty queue while other queues held
work; horizontal filters concealed later choices. Dense administration rows
compressed identities, scopes and actions, and the Company route lacked a visible
return to operations.

Orders, Stock and Deliveries now show wrapping counted queue/filter choices.
Empty order results offer the next populated queue or Clear search and filters.
Company administration has a visible back action, company identity, refresh and
wrapping Locations/Team/Applications controls. Warehouse/member cards retain full
identity and access/address details with actions below. Team puts members first,
adds email/warehouse search and visible role choices, resolves warehouse IDs to
names, and shows invitation expiry when available. Existing Company authorization,
mutation, confirmation and form methods match their pre-change source exactly.

Verification: Admin Flutter analysis and shared company Dart analysis report zero
issues; architecture boundaries pass. Six focused form/stock checks pass, including
Company Owner roster layout at 320px with 200% text and warehouse-name search.
The sanctioned Admin dev debug APK builds and updates the connected Redmi in place.
Package and signing SHA-256 match; version code remains 1. Android first-install
time remains 2026-09-28 21:51:55. Native captures show the updated Stock and
Deliveries controls and retained company data; company access loads. Native Team,
Locations and order shortcut flow acceptance remain for user manual testing.
Full harness/emulator/UI matrices remain deferred under presentation build mode.

### Admin navigation correction after user review — 2026-10-07

User rejected the first wrapping chip treatment as visually worse and reported
poor navigation. The corrected design restores compact underlined secondary queue
tabs for Orders, Stock and Deliveries, with counts below labels and all choices
sharing one row at normal text size. Enlarged text uses horizontal scrolling.
Item requests is a distinct text action rather than a queue choice. Company
Locations/Team/Applications use the same secondary tab treatment.

Operations and Company administration now share one CompanyNavigationBar with
Orders, Stock, Deliveries and More. Administration selects More and returns the
chosen operations destination directly; system back retains the previously
selected page. Admin routes return a typed destination while the shared screen's
existing onMore callback remains compatible with other callers. Workspace switch
and sign-out behavior retain their prior authorization handling.

Seven focused form/stock/navigation checks pass, including More retaining all
four destinations and returning directly to Stock, and roster search text
surviving scrolling at 320px with 200% text. Admin and shared company analysis
report zero issues; architecture boundaries pass. The sanctioned dev debug APK
builds with matching package, version and signing certificate for the in-place
phone update. Native navigation acceptance remains for user manual review;
full harness/emulator matrices stay deferred under presentation build mode.

The correction APK installation was attempted but Android rejected it with
`INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`. The phone still runs
the earlier chip-layout build; the navigation correction is implemented, analyzed,
focused-tested and built but is **not installed**. Retry awaits the user's response
and acceptance of Android's installation prompt. No uninstall, data reset,
downgrade or permission bypass was attempted.

The user explicitly authorized retrying the corrected update. The subsequent
in-place `adb install -r` succeeded; the correction APK is now installed. The
Admin package remains `com.sarisupply.sarisupply_admin`, version code 1, and
Android's original first-install time is preserved. Native visual review of More
and its destination switching remains separate from the passing route test.

Native capture after the successful correction install confirms the compact Stock
filter strip, then Orders with all four counted queues visible on one row, separate
Item requests, the populated-queue shortcut and retained company order counts.

### Admin task hierarchy after phone critique — 2026-10-07

Orders, Stock and Deliveries now use compact task headings with an explicit
Warehouse scope label. Order rows include a short reference and date/time, keep
store identity prominent, and use a quieter total. Ready contains packed orders;
On route contains dispatched/in-transit orders; receipt completion is shown as
Received without changing payment facts. Receipt review remains visible.

Deliveries use Drafts / On route / History. Rider assignment does not move a
draft into On route. Rows lead with destinations and the full saved rider name
or email, with reference/time below. Dispatch delivery is the filled primary
action; Cancel draft is in the delivery menu with the existing reason form.
Contact/address expands separately from stop items. Backend transitions, role
checks, scoped drafts, stable operation IDs and local data remain unchanged.

The persistent fourth destination is now Company, with Warehouses / Team /
Applications inside. Item requests is under Orders → Order actions. All four
main destinations stay present inside Company administration and return directly
to operations.

Verification: 23 focused queue/layout, form, stock header and navigation checks
pass. Admin analysis has no issues and the architecture boundary check passes.
Shared package analysis also has no issues. The Admin development debug APK
build succeeds using the configured development backend. Package/version and
signing certificate checks match the installed Admin app. The in-place update
succeeded on Redmi vk55gmzh6tgabqey at 14:42:28, preserving versionCode 1 and
the original 2026-09-28 first-install timestamp. The activity starts and
warehouse orders refresh successfully without requiring sign-in again.
Full harnesses and end-to-end flow testing remain deferred to user manual testing.

Phone review shows the Warehouse header, all four bottom destinations and the
On route queue with 10 order records, short references and full dates. Refresh
completed with no offline banner. User then requested centered empty queues:
the icon, message and next-queue action now center within the remaining viewport.
A focused geometry check passes. The native capture also led to a tighter normal
phone footer; large text and long totals retain the readable stacked layout.
The final adjusted in-place APK update succeeded at 14:48:13 with the original
first-install timestamp intact. Native capture confirms the compact footer and
fresh warehouse access: 2 Awaiting, 8 On route and 2 Received records loaded.
The empty state is covered by the geometry check; its final native capture is
not available because the phone is showing populated Awaiting orders.
Expanded Deliveries and Company page native acceptance remain manual checks.
