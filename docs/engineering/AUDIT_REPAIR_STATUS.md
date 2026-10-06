# Application audit and repair status

Approved on 2026-10-05. Scope: POS first, then Admin and Driver, with real accounts
and shared business data. Preserve branding, existing work, and durable records.

## Work packages

- [ ] Explicit backend configuration, safe startup, shared Android Google sign-in.
- [ ] Operation-specific inventory synchronization and legacy queue recovery.
- [ ] Exact checkout/report arithmetic and server-authoritative customer credit.
- [ ] Shared procurement and warehouse operations with retry-safe transitions.
- [ ] Authenticated Driver assignments and durable delivery acknowledgments.
- [ ] Real Admin reports and procurement data.
- [ ] Complete consistent archives and safe restoration.
- [ ] Targeted phone usability fixes and truthful printing/export feedback.
- [ ] Final regression, emulator, build, security, and offline review.

## Initial evidence

Flutter analysis and architecture boundaries passed. TypeScript compilation passed.
Nine gateway and twenty financial/model tests passed. Source inspection found:
internal backend fallback; missing Android Admin Google client ID; hardcoded Driver
identity; count-only inventory upload routing; client-minted credit allowances;
demonstration Admin data; incomplete archives; unscoped delivery mutations; fake
printer success. Passing static checks do not establish operational readiness.

## External gates

The operator confirmed no hosted backend is deployed. Development HTTPS hosting,
account eligibility, IAM, live App Check, release signing, measured capacity,
multi-device and phone acceptance remain pending. No paid fallback or production
publication is authorized by local repair completion.

## Repair evidence (2026-10-05, work in progress)

Implemented locally:

- Required HTTPS backend origin with safe setup errors; shared Android Google OAuth client selection and bounded startup screens.
- Inventory uploads route receiving, adjustment and transfer commands correctly. New local movements leave canonical stock intact and follow remote changes; legacy absolute operations retain their existing recovery path.
- Customer credit uses server reservations. Payment attempts retain their IDs and cart across restarts, reject edits/discard, and can cancel unused reservations online with retry-safe tombstones. Debt repayments queue ordinal-bearing checkout events atomically.
- Daily reports calculate line totals, separate cash refunds/voids from other tenders, and use Philippine business dates. Server accepted-operation aggregates update transactionally and ignore duplicate replays.
- Admin reports and procurement read authenticated selected-store data, with explicit unavailable/empty states instead of demonstration records. Report layout passed a 320-pixel, 200% text regression.
- Driver uses Google identity and assigned workspaces. Delivery proofs/statuses have a durable local outbox and acknowledged synchronization; revoked assignments cannot submit proof. Proof quantities and collection are checked against the stored manifest.
- Complete encrypted archive snapshots include all local tables; restoration validates an isolated copy and refuses occupied workspaces. Printer transport remains unavailable and its button no longer claims success.
- Purchasing server transitions enforce Owner authority, stable receiving IDs, purchase/proposal replay checks, ordered transaction reads, available-stock reservations, and bounded partial pick/pack transitions.

Verification completed during implementation:

- Workspace Flutter analysis: zero issues after the purchasing adapter change. Architecture boundaries: pass. TypeScript compilation: pass.
- Inventory package: 60 tests passed before the latest projection/recovery additions; focused follow-ups passed 23 synchronization/stock tests, 18 archive/customer/stock tests, and 15 checkout durability tests.
- Models: 11 report/customer-credit tests passed. Firebase adapters: 10 focused tests passed. POS: seven payment/controller tests passed. Admin: narrow-phone report regression passed.
- Checkout/refund emulator group: 12 tests passed; delivery/receiving group: six passed; purchasing group: three passed.
- Subsequent checkout/delivery group: 14 test assertions passed, but Firebase CLI reported an unexpected teardown error after emulator shutdown; this command is not recorded as a fully passing verification gate.
- Admin web release compilation, Driver devDebug APK and POS devDebug APK passed without a hosted origin. These are compile checks of the setup-incomplete state, not deployable operational builds. Later source edits require final rebuilds.

## Repair continuation (2026-10-06)

Additional implementation in the working tree:

- Purchasing commands use an immutable durable outbox and real server warehouses,
  catalog products, suppliers and human identities. Owner actions require fresh
  canonical record IDs; older local records remain preserved for review.
- Purchase receiving records batch/expiry and actual last-purchase cost. Packing
  creates shared manifests; Owner dispatch uses those manifests and active Driver
  assignments. Delivery writes branch stock and collection facts once. Returns
  remain unavailable until Owner receipt chooses restock or quarantine.
- Refunds and voids bind exact receipt units, price, quantities, tender and scope.
  Exact-intent server Owner approval is required. Credit compensation decreases
  debt without replenishing the allowance; already-repaid debt needs review.
  Approval retries preserve the original operation ID and immutable event.
- Destination branches discover and cache dispatched transfers with pagination.
- Diagnostics can restore and inspect a separate complete recovery workspace.
  Occupied original workspaces and pending queues remain intact. Blocked queues
  appear as warnings, not successful synchronization.
- Inventory valuation includes pending local movements and explicitly marks
  unavailable branch cost/profit instead of estimating them.
- Production Android release requires real signing credentials. Client build
  settings validate HTTPS origins and the public web App Check key. See
  [client build settings](CLIENT_BUILD_SETTINGS.md).
- Shift overflow and queue labels were corrected. Reports had a double-decoded
  shift and an unbounded tab layout; both are repaired, with wrapping phone cards.

Measured continuation checks:

- Flutter analysis passed with zero issues after the final report layout change.
- TypeScript compilation and architecture boundaries passed.
- Twenty refund/purchasing/delivery emulator tests passed with successful CLI exit,
  including current warehouse reassignment, exact approvals, immutable manifests,
  branch stock reconciliation and held/quarantined returns.
- Eighteen local checkout/customer tests, eight local refund/recovery/purchasing/
  delivery tests, four diagnostics tests and two Shift widget tests passed.
- Shift and Reports regressions passed on a 320px phone with 200% text scaling.
  Reports coverage includes Daily Sales and Inventory Valuation.
- Client build validation passed six positive/negative cases; no real backend URL
  was used in that validation. Private server settings checks passed project
  validation, restrictive file permissions and existing PIN-pepper preservation.

## Presentation priority

The operator now requests a running presentation later today with internet,
using the real Firebase Development backend and Deno Deploy. Noncritical audit
expansion is paused. The operator provided the Development service-account file. It was moved outside
the repository with 0600 permissions; Firebase Auth and Firestore access passed.
Private server settings and a persistent PIN pepper are prepared outside the
repository. Deno Free authentication passed and the Development API app was created.
The cloud build compiled successfully but failed during artifact packaging; a
cloud compiler subsequently stalled. Local TypeScript compilation passed; a new
revision uploads compiled output with runtime dependencies only via the REST API. Firebase App Check API
access passed after the operator enabled it. The operator-selected Admin account
has its Development role and custom claim. Server secrets are masked and limited
to production/preview runtime contexts inside the Development app, excluding builds. Revision `42wrrxfpnyd4` deployed successfully and returned the application JSON
from its public HTTPS origin; connected-client acceptance remains pending. The incomplete CLI upload revision
was cancelled; the replacement compiled artifact was accepted by the REST deploy
endpoint, then passed runtime warmup and routing. A local TypeScript build and whitespace
checks for the edited deployment/status files passed. Whole-worktree whitespace
checks still flag pre-existing README Markdown line breaks. Phone USB authorization
is intermittent. The installed apps are release builds, so `run-as` business-data
backup is unavailable. Installed APKs were copied for signing comparison before
`adb install -r` updates, which retain app data. POS and Driver Development debug
APKs built against the real origin in 26.9s and 17.3s respectively; update results
passed. Both APKs were installed as matching-signature updates without clearing
app data; POS required `adb install --no-streaming -r` after streamed installs were
blocked by the phone. Post-update private data backups succeeded for both apps.
Driver opened its Google sign-in screen; signed-in delivery workspace and POS
activation still require live acceptance. Both phone-generated App Check debug
tokens were registered in Development via the official API.

Remaining before acceptance:

- Deploy Development HTTPS API, configure real App Check and Admin authority,
  build clients against the deployed URL, and rehearse actual phone workflows.
- Review outstanding legacy reconciliation, incomplete historical report coverage,
  branch cost records, blocked-operation recovery and Driver collection/remittance
  visibility. No unavailable financial values may be presented as verified totals.
- Final regression/security/offline review, full harness and final builds. The
  full harness remains deferred while repair implementation is still active.

No application is declared fully functional or production-ready yet. Existing
installed phone apps and their business data have not been replaced or cleared.

Admin web registration uses Fraud Defense (reCAPTCHA Enterprise), because the
console deprecates Classic. The shared gateway now accepts the public provider
setting `enterprise`, retaining `recaptcha-v3` for existing keys. Firebase package
analysis passed with no issues and 11 focused configuration/HTTPS tests passed.
The supplied public Enterprise site key matched the saved Firebase registration.
Admin web built in 40.7s and deployed to `https://sarisupply-dev-aracena18.web.app`.
A clean Hosting-only staging folder resolved the CLI rejection of an artifact
outside its project directory. Fixed-name Flutter assets now revalidate on reload.
No attestation bypass or secret key is included in client builds. Full harness remains
deferred under the repository build-focused instructions.

Presentation steering: all three roles must run as Android applications on the
same phone, including Admin. Web is no longer the acceptance target. Admin
Development Android previously copied POS/Driver registration IDs and lacked an
Android OAuth client. A dedicated Development Firebase Admin Android app was
created for the existing `com.sarisupply.sarisupply_admin` package, preserving
update compatibility. Its debug signing SHA-1 is registered, generated SDK
configuration has Android and web OAuth clients, and the Deno API allowlist includes
the Admin app ID. Its APK built in 56.4s and installed successfully with a matching
signing certificate, retaining app data. Two native Firebase-bootstrap checks
passed, and fresh whole-repository analysis reported no issues (28.2s). Live Admin
sign-in and all-role business-flow acceptance remain pending.
