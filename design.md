# SariSupply design contract

Read this before changing UI, UX, or user-facing copy. Update it when an accepted design decision changes.

## Identity

Warm Utility: the supplied SariSupply symbol, the “SariSupply” name typeset in the bundled Instrument Sans font, and POS, Admin, or Driver as the role label. Use the symbol SVG without changing its proportions; do not use the combined logo artwork for the name. Product screens carry the task title and useful context; entry screens carry the full brand. No Flutter scaffold branding or development status in product screens.

The approved visual source is the local SariSupply Design System v1 in `sarisupply_design_system_v1`, implemented by `packages/sarisupply_design_system`. Use its Warm Utility direction: warm paper backgrounds, white working surfaces, ink typography, and selective orange for primary actions and brand emphasis. Use the defined semantic colors for success, warning, error, and information; every state must also have a label or icon.

Use locally bundled Instrument Sans under its SIL Open Font License, with the package's Inter/Roboto/Arial fallbacks. Follow the design system typography scale and respect system text scaling; never shrink text to fit.

## Layout and components

Material 3; use the shared SariSupply icon family for core product navigation and Material icons for supporting actions. Buttons, inputs, and cards follow the design-system radii. Use its 8pt spacing scale. Page padding is 16 below 600 logical pixels, 24 above. Constrain reading width on larger screens.

One task title, then context, then the task, then recovery/status. Verb-led actions; no repeated instructions, promotional filler, or empty dashboards. Preserve units, validation, offline status, and consequences. Native task navigation; no placeholder tabs.

Forms occupy a full page below 600 logical pixels and a constrained dialog above. One scroll area for form content; actions remain reachable with the keyboard open. Preserve form controllers, draft/operation IDs, and non-secret selections during width changes. Secret values clear on failed authentication and dismissal.

Management uses persistent, labeled Overview, Branches, Team, and Devices navigation on phones and side navigation on wide screens. Team uses visible role-filtered Cashiers, Managers, and Invitations subtabs. The Owner overview uses the selected branch's local sales and inventory cache and must disclose that scope; it must not present one device's records as store-wide totals. One contextual creation action. Cashier sign-in opens phone Checkout after access verification; Lock returns to cashier selection and disposes Checkout without deleting local business data. Automatically open the only authorized stock branch when only one store is available; multiple stores or branches require an explicit choice.

## States and accessibility

Distinguish loading, empty, no matches, error, pending submission, saved locally, sync pending, and needs review. Synchronization errors retain inventory and pending work. Pending counts remain reachable from the status summary. Exact barcode matches display the matched unit and its exact price. Retry preserves operation IDs. Confirm destructive actions and Admin review decisions with their consequences.

Minimum 48×48 tap targets, readable contrast, labeled controls, keyboard access, and 200% text scaling. Follow [Flutter’s accessibility checklist](https://docs.flutter.dev/ui/accessibility). Test 320, 390, 600, 1024, and 1280 widths; test device usability separately from screenshots.

## Approved examples

- Entry: storefront / SariSupply / POS / “Sign in with Google”.
- Incomplete POS startup configuration: shared identity / “POS setup is incomplete. Contact your administrator.” Do not offer retry for missing build configuration.
- Cashier: “Cashier sign in” / name or cashier ID / PIN / “Sign in”; roster errors offer “Retry names”.
- Inventory: branch / search / filters / sync status / product name, stock in base units, base price. Expand for sale units and authorized actions.
- Count: “Physical count” / product, current stock, base unit / entered quantity / reason / “Save count”. Success: “Saved locally · Sync pending”.
- Admin: “Review application” / business and branch summary / rejection reason / “Approve” or “Reject”, followed by confirmation.
- Driver: shared identity / “No delivery workspace available”; no fake delivery actions.

## Future scope

Checkout is the cashier’s primary task: local shifts, search/rear-camera barcode scanning, saved carts, cash/manual QR and immutable receipts. Driver stops and delivery actions remain a future milestone. Dark mode, localization, and backend enrichment of invitation store names remain separate work. Invitations retain an identifiable store reference until the API supplies names.

## Driver foreground location sharing

Company-invited riders use the same Warm Utility “My Route” presentation as
legacy drivers: route progress, the next stop, upcoming/completed stops, amounts
due, directions, and a reachable Record delivery action. Keep company records,
authorization and durable proofs on the company workflow. An invitation must
not switch riders to a generic operations layout. Company GPS and signature
capture remain separate feature work; do not display unsupported actions.

For the approved presentation slice, Driver offers explicit Start sharing location, Stop sharing and Update now actions on an assigned active run. Explain that sharing pauses outside the Driver app, including Maps and screen lock. POS dispatch shows the latest shared coordinates, accuracy, capture/receipt age and sharing state, with external Maps. Older or unconfirmed locations are last known, never claimed as live. No fake locations or map movement.


## Company ordering and dispatch — approved presentation scope

Admin company operations use Orders, Stock, Deliveries and Company navigation.
Company preserves warehouse/staff administration; Store Owner ordering is available
from POS Inventory. Rider sees assigned delivery stops and minimum destination
information. Use existing theme, 16px phone/24px wide padding, wrapped actions
and 48px touch targets. Product selection uses search and a bounded cart rather
than a long catalog form. Contact, quantity, receipt and delivery forms save scoped
drafts; review quantities and totals before submitting. Show pending, blocked,
shortage, partial delivery and reconciliation states explicitly. Collected cash,
verified QR and actual remittance remain separate. Receipt does not increase
retail stock until the trusted server accepts it. Keep internal authorization
revision IDs out of normal operation screens.

The Admin Company page keeps Warehouses and Team visible beside each other.
Company Owners manage invitations and staff in Team. Warehouse Operations sees
an explicit owner-access message in Team, with workspace switching when available;
it does not read the company roster or expose staff-management actions.


## Operation confirmations

Warehouse Stock keeps Add product visible for Company Owners and Receive stock
visible for authorized operations, with unavailable actions disabled during initial
loading, offline recovery or access denial. Render the header and a labeled loading
state immediately; keep saved stock visible during refresh. Filters scroll
horizontally within their own natural height. Provide an explicit Refresh stock
action without changing server authorization or ledger behavior.

Stock product details use a phone sheet with product/SKU identity, warehouse
context and wholesale price. Emphasize available quantity with its unit and
explicit stock status; group reserved, in-transit and quarantined balances below.
Keep Receive stock as the primary reachable action. Group product edits separately
from collapsed Stock corrections. Show transit write-off only when transit stock
exists, with a destructive treatment. Preserve role and offline restrictions.
The Stock header uses primary Receive stock and secondary Add product actions,
with stacking on narrow screens or large text; omit inactive scanner controls.

Successful company product, stock, order, and delivery actions use a short-lived
floating confirmation. Do not leave “Saved” as a persistent page banner. Keep
meaningful unresolved states such as sync pending, blocked evidence, and needs
review visible until resolved.


## Checkout notices and price recovery

Cart additions, quantity validation, barcode misses and temporary scan failures
use dismissing floating notices. Stale cart quotes offer Review prices; approval
is required before replacing quoted prices. Distinguish cart limits, changed
prices, connection and shift failures. Access denial, pending sync and unresolved
local durability failures remain visible as operational states.

## Store replenishment and sourcing requests — 2026-10-07

Store ordering opens a persistent searchable selling catalog with a separate
local cart and reachable Review order action. Add/remove/quantity edits do not
refresh catalog data. Keep scroll, search, loaded pages and cart quotes while
refreshing in the background. Display selling units, prices, availability freshness
and explicit Out of stock · Backorder labels; warehouse acceptance remains required.
Prefill branch delivery details and retain saved scoped defaults, with drafts taking
precedence. Changed quotes require explicit price review before submission.

Suggested reorder uses this branch's device stock, threshold 10 and target 20
retail base units. Require owner-confirmed retail/company unit mappings, support
selected additions, and preserve existing cart quantities. Sourcing requests stay
separate from orders; Store Owner sees request history/responses, company operations
can respond or close within warehouse scope. Offline entries remain drafts, and
submission IDs survive uncertain acknowledgements. Form draft writes are serialized
and flushed before route dismissal to prevent draft loss or resurrection.

Store Owner sourcing requests stay in POS Inventory → Order from SariSupply →
Request an item / View requests, with a visible creation action and request history.
Admin's incoming sourcing inbox opens from Orders → Order actions → Item requests,
scoped to the selected warehouse. Keep it separate from stock,
warehouse setup and purchase-order status; do not place a loose requests link
under the Orders header. Warehouse staff respond to requests rather than creating
requests on behalf of independent stores.

## Store application review — 2026-10-07

The supplying Company Owner reviews store applications in Admin / Operations →
Company → Applications. Keep this tab visible only to Company Owners;
Warehouse Operations and Store Owners cannot review or approve applications.
Show the business name, first-branch name and address, and submission date in a
searchable pending list. The detail screen presents the complete submitted
business and first-branch fields and the submission date. Keep applicant and
reviewer identity in audit data without exposing retail records. Approval confirmation
states that it creates the store, first branch, and applicant's Store Owner access.
Rejection requires a clear reason that will be shown to the applicant. Provide
loading, retry, empty, no-match, pending submission, and success states; refresh
the list after a decision. Keep the page responsive and the review actions
reachable at 320px and 200% text scaling.

Warehouse Orders keep the queue compact: store, total, status, item count and
time. Tapping an order opens a focused modal with structured item rows and totals,
a short next-step cue and a reachable primary fulfillment action. Keep changes,
rejection and payment verification in secondary actions; proposals require store
approval. Fold delivery and payment details until requested. Keep the full order
reference in the modal. Packing fields identify item, unit and ordered quantity;
proposal fields identify the item for quantity and price.

Store Owner order review requires an explicit payment choice: Cash on delivery
or QR payment. Explain where QR instructions come from and that payment remains
pending until the supplier confirms receipt. Disable QR when the supplier has
not configured payment instructions. Show the selected method in Store Owner
history and Admin order details. Driver sees QR · collect no cash for QR orders;
show the amount due only for cash-on-delivery orders. QR confirmation remains a
manual supplier action; do not imply that scanning or submitting an order moves
money automatically.


## Store overview hierarchy — 2026-10-07

The Store overview keeps the store name and selected branch as compact context
beneath Store management. Today’s net sales occupies one full-width card, with
transaction count and the secondary Sales report action below. Keep monetary
digits together; allow horizontal scrolling for long amounts at larger text
sizes instead of shrinking text or splitting an amount across lines. Show
“Sales from this device only” beside expandable scope details. Do not imply
store-wide reporting or a verified synchronization state.

Open inventory is the primary action. Low-stock rows separate product/SKU
identity from quantity and explicit Out of stock / Low stock labels, with
semantic colors and dividers. Stack row groups and summary actions on narrow
screens or large text. Preserve the ten-base-unit threshold, saved-device
inventory scope, five-item preview and existing branch/report navigation.


## POS Reports & Archival — 2026-10-07

Reports retain Sales, Stock, Backup and Printer tab order and entry indices.
Use compact text navigation, visible branch/device scope, one main value per
report, and grouped label/value rows for supporting figures. Keep date selection
and preview/clipboard actions near the summary. Labels describe copying CSV
rather than downloading files. Payment-method totals include credit; do not
label them as collected cash. Expected drawer cash is not a physical count.

Stock separates retail value, unavailable purchase cost/profit, stock status,
expandable movements and product details. Low stock means 1–10 base units;
zero or negative stock is out of stock. Disclose local pending movements and
report generation time. Avoid large placeholder values and unsupported trends.

Backup follows Create, Copy and Verify. Explain password requirements and that
creation is temporary until the user copies and saves the encrypted JSON.
Verification checks the generated archive, not an external saved copy. Keep
the two-owner-controlled-copy guidance and recovery entry. Preserve encryption,
verification and retention policies. In-progress actions disable duplicate taps.

Printer offers vertically arranged 58/80 mm choices and a test preview. Explain
that printer connection and cash drawer control are unavailable and the choice
applies to this page’s previews. Receipt previews use a full phone page or a
bounded wide dialog, preserved receipt columns with scrolling, a labeled close
control and one Copy receipt text action. Test previews are sample data. Daily
report previews disclose placeholder shift/count metadata and are not recorded
shift closures. Controls and supporting rows stack at larger text sizes.

## Driver task hierarchy — 2026-10-07

Signed-in Driver workspace selection uses compact SariSupply identity, a clear
workspace heading, and rider assignments first. Keep other company roles in a
secondary expandable group with the existing Admin guidance. Invitation acceptance
stays explicit, with readable expiry and a full-width action. Preserve sign-in,
refresh, sign-out, and access-recovery behavior.

My Route uses compact company context, an assigned-route summary and honest
“stops recorded” progress. Give the next destination a white bordered working
surface, full-width name/address, quantity/payment context and View stop details.
Upcoming stops are readable previews without inactive navigation arrows; show all
remaining loaded stops. Recorded proof, partial delivery and pending sync remain
visible and distinct from store receipt or financial settlement.

Stop details keep the destination first, show the actual saved delivery stage,
and omit optional items/collection stages when they do not apply. Group the
existing delivery summary below it. Keep contact and instructions in an expandable
section, and one reachable primary action. Use shared type, color and radius
tokens; bright-orange actions use ink text/icons for contrast. Preserve 48px tap
targets, wrapping at 200% system text, field order, validation, durable drafts,
operation IDs and existing authorization.


## POS management lists — 2026-10-07

Branches, Team and Devices show compact store context, an explicit page heading
and a short task description. Creation remains the primary action where permitted;
Refresh is secondary. Move Catalog and stock below the management list.

Team exposes Cashiers, Managers and Invitations as wrapping choice tabs without
horizontal scrolling. Managers have a View invitations route. Cards separate
name/code identity, readable status and assigned-branch count or All branches.
Invitation status active displays Awaiting acceptance. Device IDs remain visible
for identification; do not invent device models, online status or last-seen data.

Search filters loaded records by identity, code and saved status. When another
page exists, disclose that search covers loaded records and keep Load more
reachable even with no matches. Show loaded counts rather than implying total
store counts. Empty states describe the next available step. Destructive menu
items use error color and icons, retain confirmation and hide empty menus on
inactive branches. Controls and cards wrap at large text sizes.

Creation/access forms explain temporary PINs, Google account acceptance and
branch scope. Selected branch count and branch code help distinguish locations.
Keep authorization, operation IDs, validation and PIN privacy behavior intact.
Changing stores preserves the selected Branches or Devices list type.


## Checkout continuous scanning — 2026-10-07

Checkout keeps search and scanning above the scrolling cart and payment below it.
Show cached catalog products when the cart is empty and during explicit search;
otherwise prioritize the working cart.
The camera stays open after additions and barcode misses. Show the last added
product, exact selling unit/price, editable quantity and cart total. Confirm an
addition only after the local draft saves. A held barcode adds once; use + or
Scan same item again for identical items. Manual barcode entry stays secondary
and expands for camera failures. Done scanning returns to the same cart.

Cart and scanner use − / quantity / + controls. Tapping quantity opens whole-number
entry with existing quantity/cart limits. Block scan acceptance while editing,
saving, inactive or covered by another route. Revalidate access before scans and
on resume. Preserve durable drafts, exact units, quoted-price review and receipts.


### Scanner presentation refinement — 2026-10-07

Keep the barcode camera dominant, with a simple aiming guide and Ready/Updating
status. Remove instructional paragraphs. Place the last added item, exact unit
price and quantity controls in a compact bordered card. Use short Added to cart,
Scan again and Enter barcode labels; retain explicit failure/access recovery.
Keep Done with cart total fixed below the scrollable controls. The aiming outline
is visual guidance, not a promise that detection is restricted to that area.


## Store supplier ordering hierarchy — 2026-10-07

Company Orders uses a clear New order action, secondary sourcing requests,
search over loaded orders, and All / In progress / Completed filters. Cards show
a shortened order reference, status badge, total, branch, product count and
recorded date. Full references remain in details. Distinguish Review changes
from Awaiting acceptance. Expand items and line totals, with delivery/payment
details secondary. Keep revised-order approval, cancellation and actual receipt
actions under their existing authorization and confirmation policies.

Product browsing shows a single warehouse as compact context; multiple warehouses
retain a selector. Product identity and selling price have room above wrapping
availability and quantity controls. Show explicit Add to order, editable quantities
with selling units, and line totals. Keep availability freshness and backorder
labels honest. A separate pinned cart summary shows the limit, total and Review
order action. Suggested reorder separates device stock from suggested company
selling quantities, exposes Change match, and identifies items already in the
cart. Detailed threshold/conversion guidance stays expandable.

Review uses one scroll area for cart, delivery and payment, with a labeled Close
review control and pinned total/Submit order. Quantity changes remain possible
before confirmation. Validation reveals delivery/payment sections and shows a
short error beside Submit. Preserve integer-centavo calculations, explicit
payment choice, price-change acceptance, draft writes, pending submission retry,
and warehouse acceptance; this redesign adds no automatic order commitment.

### Admin Company Owner and warehouse workspace refinement — 2026-10-07

Orders, Stock and Deliveries use compact underlined secondary queue tabs with
counts below their labels. All queues share one row at standard text sizes;
enlarged text uses horizontal scrolling to preserve readable labels. Item requests
is available under the Orders action menu. An empty order queue offers the next populated queue;
a filtered empty result offers Clear search and filters. Existing loaded records,
fulfillment status, payment policy and server authorization remain authoritative.

Company administration shares the persistent Orders / Stock / Deliveries / Company
bottom navigation with operations. Company is selected while viewing administration;
tapping another destination returns directly to that operations page. System back
returns to the previously selected page. Company identity, role and refresh remain
visible. Warehouses, Team and Applications are secondary underlined tabs, visually
distinct from the global bottom destinations.

Warehouse/member entries grow with their content: identity and address/access
details precede status and actions. Scope labels describe access rather than
implying warehouse operational status. Team puts members before invitations, with
visible role choices and local search by email or warehouse name. Search text
survives scrolling. Invitations show expiry when supplied. Warehouse Operations
retains the owner-only Team message and never requests owner rosters. Removal and
revocation still require confirmation; forms and stable operation IDs retain
their existing behavior.

### Admin task hierarchy after phone review — 2026-10-07

The toolbar labels the selected Warehouse above its name, separate from the account
avatar. Task headings use the compact section size. Order rows lead with store
identity, short reference and date/time, then status, item count and total. Ready
contains packed orders; On route contains dispatched/in-transit orders. Store
receipt completion appears under Received; payment confirmation remains separate.
Existing receipt-review indicators take priority over a completion label.

Delivery queues use Drafts / On route / History. Assigning a rider leaves a run in
Drafts until dispatch. Rows lead with destinations and the full saved rider name
or email; short reference and creation time are secondary. Expanded drafts have
one filled Dispatch delivery action; Cancel draft is in Delivery actions and
retains the reason form. Contact/address details expand separately from stop
items. Preserve confirmations, scoped drafts, authorization and stock transitions.

Empty order queues center their icon, message, explanation and next-queue action
horizontally and vertically in the remaining viewport below the queue tabs. Long
content can still scroll at enlarged text sizes. Standard phone rows keep status,
item count and total on one footer row when they fit; enlarged text or long totals
use a stacked footer without shrinking or truncating money.
