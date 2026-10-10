# AUTH-01 authorization contexts and compatibility contract

Date: 2026-10-06. Task: [AUTH-01](../../SARI_SUPPLY_TASKS.md#auth-01).
Status: independently reviewed documentation contract; coordinator integration pending.
This document specifies target behavior. It does not add runtime authorization,
provision an identity, allocate a deployed schema version, or migrate data.

The [canonical architecture](../architecture/SYSTEM_ARCHITECTURE.md) controls
business ownership and permissions. The [current state](../engineering/CURRENT_STATE.md)
records gaps. Retain compatible [identity contracts](../superpowers/specs/2026-09-26-firebase-identity-tenant-auth-design.md)
and [free-platform contracts](../superpowers/specs/2026-10-04-free-production-platform.md).
AUTH-01 has no prerequisites; there are no prerequisite handoffs to integrate.
Downstream implementation starts only after this contract's reviewed integration.

## 1. Identity, principal and context

Identity proves who authenticated; a principal proves the business role used for
one action. A request has exactly one selected context. A human with several
memberships switches contexts explicitly; roles, capabilities and scopes never
merge across company, platform, store or cashier sessions.

| Principal | Establishment | Authoritative checks for each action |
| --- | --- | --- |
| Company Owner | Trusted administrative provisioning binds a verified Google/Firebase UID to the supplying company. | Active company and matching active Company Owner membership; company/resource ownership. Platform Admin alone cannot provision through a public client command. |
| Warehouse Operations Manager | Company Owner invitation accepted by the matching verified Google identity. | Active company, matching active operations membership, finite assigned warehouse IDs, active company-owned warehouse and action permission. |
| Rider | Company Owner invitation accepted in Driver; roster membership follows acceptance. | Active company and rider membership, warehouse scope, active roster and current run assignment. Membership alone cannot start or view another rider's work. |
| Store Owner | Existing Google merchant application and platform approval. | Active merchant and matching Owner membership with explicit all-branches authority; resource belongs to that store. |
| Store Manager | Existing Store Owner invitation and acceptance. | Active store Manager membership and explicit branch scope; delegated action, including separate receiving permission where needed. |
| Cashier | Existing branch assignment and PIN login on a registered POS device; no Google account required. | Active store/branch/device, cashier status/assignment, credential version and exact cashier grant/session. Device UID and cashier ID are separate. |
| Platform Admin | Existing preauthorization, Google identity, `sarisupplyAdmin` claim and active server record. | Both claim and active server record; allow-listed platform action. No implied company/store membership. |

Firebase token verification must establish correct environment/project, signature,
issuer, audience, expiry and revocation/account state under the approved transport
policy. App Check checks the actual permitted application; it is not a business
role. Company and invitation entry require a verified token email and Google
identity (`firebase.sign_in_provider == "google.com"` for new company entry).
Email, provider, UID, claims and permissions supplied in request data are not
evidence. Existing store/platform entry contracts remain Google based; do not
change cashier authentication or cryptography.

For invitation matching use trimmed lowercase token email, as the existing store
invitation code does. Never remove dots, strip `+` aliases, infer domain ownership,
or equate a display name with a verified account. At acceptance bind the UID;
later email changes do not transfer membership. Administrative provisioning must
resolve and verify its intended UID/email through trusted identity tooling.

Company checks require the active identity container and exact selected role
grant, including that grant's status, scope and revision. Merely holding another
company role does not satisfy the action's selected role.
Checks occur against current trusted records inside the transaction that performs
a privileged mutation. Recheck membership, company/store, warehouse/branch,
device and resource assignment rather than authorizing from a stale workspace,
projection, cached claim or client-selected ID. Ownership assertions include the
record's IDs and parent root. Missing, malformed, unknown, removed or inactive
roles/scopes fail closed. A null or empty scope never means all locations.

## 2. Additive schema boundary

These are logical Firestore paths and fields for downstream implementation.
`authorizationVersion: 1` below is the proposed new contract version, independent
of existing domain/SQLite versions. The coordinator must reserve its final value
and shared wiring before an implementing worker writes a schema or registry.
No AUTH-01 writes, indexes, migrations, rule allowances or dependencies are added.

| Record | Proposed additive contract | Ownership / trust |
| --- | --- | --- |
| `companies/{companyId}` | `companyId`, `status: active\|inactive`, `authorizationVersion`; business details owned by SETUP. | One supplying company in this baseline. Never derive its ID from a current merchant. |
| `companies/{companyId}/memberships/{uid}` | `companyId`, `userId`, `status: active\|removed`, `revision`, `createdAt`, `updatedAt`. | Trusted identity/status container. Every action selects and verifies one independent role grant; no role union. Distinct platform/store memberships may coexist for the UID. |
| `companies/{companyId}/memberships/{uid}/roles/{role}` | `companyId`, `userId`, `role: companyOwner\|warehouseOperations\|rider`, `status: active\|removed`, `scope`, `revision`, `createdBy`, `createdAt`, `updatedAt`; invitation ID if invited. | Trusted explicit grant. One UID may hold several company roles through separately authorized grants; Owner provisioning cannot imply Rider/Operations, and invitation cannot overwrite Owner. |
| Company role grant `scope` | Owner: `{kind: company}`. Operations/Rider: `{kind: warehouses, warehouseIds: [nonempty unique IDs]}`. | Validate every warehouse as active and owned by this company. Finite list, maximum 100; no Operations/Rider all-warehouses wildcard. Changing scope is an explicit Owner operation. |
| `companies/{companyId}/warehouses/{warehouseId}` | `companyId`, `warehouseId`, `status`; details owned by SETUP. | Warehouse is company owned, never a store branch. A new warehouse is not automatically assigned to existing Operations/Rider memberships. |
| `companies/{companyId}/invitations/{inviteId}` | `companyId`, `inviteId`, normalized `recipientEmail`, `role: warehouseOperations\|rider`, `warehouseIds`, `status: pending\|accepted\|revoked`, `expiresAt`, `createdAt`, `createdBy`, `acceptedBy`, `acceptedAt`, `revokedBy`, `revokedAt`, `operationId`, `requestFingerprint`. | Owner-created; no Company Owner or platform privilege invitation. Expired is a derived terminal state when server time reaches expiry. |
| `users/{uid}/companyRefs/{companyId}` | `companyId`, `roleRefs`, `status`, `membershipRevision`, `updatedAt`. | Discovery projection only. Reread company, membership and each selected role grant before returning or acting. Never use projection status as authority. |
| Existing `merchants/{merchantId}` and child memberships/branches | Preserve IDs, Owner/Manager roles, `allBranches`, `branchIds`, status and existing wire shape. Workspace adapter may expose a Store Owner/Store Manager label. | `merchantId` remains the store business ID. Explicit all-branches Manager scope retains access to future active branches; finite branch scope does not. |
| Store Manager receiving delegation | Proposed additive membership field `permissions.receiveSupplierGoods: true\|false`, absent means false. | Store Owner grants explicitly, constrained to the Manager's current branch scope. Does not grant purchase confirmation or consent. Coordinator reserves wiring with the receiving task. |
| Existing device/cashier/grant records | Preserve `merchantId`, `branchId`, `deviceId`, cashier assignments, PIN credential version, grant binding and historical audit IDs. | No conversion to company identities, no Google requirement for cashiers, no credential reset. |
| `_authorizationLegacyBindings/{bindingId}` | Server-only reviewed manifest entry: exact legacy locator/type/IDs, resolved owner kind/ID, permitted command family, mapping revision, approval attribution/time, disposition `store\|company\|historicalOnly\|unresolved`. | Proposed compatibility metadata, not permission. Company disposition requires separately provisioned company membership. Exact key derived from canonical locator, never product/warehouse name matching. RELEASE owns migration execution. |

Timestamps are server Firestore timestamps at rest and ISO-8601 UTC at the API
boundary. Revisions are monotonic positive integers, updated atomically with
scope/status changes. Additive fields are optional on legacy records; absence
must not confer company permissions or Manager receiving rights. Company IDs,
warehouse IDs, store IDs and branch IDs are distinct typed references, even when
their strings happen to match. Company-to-store product mapping is an explicit
commercial contract outside AUTH-01; same names/IDs cannot establish identity.

Direct client writes to company membership, invitations, bindings, grants or
audit records are denied. Existing deny-by-default rules remain; scoped trusted
HTTPS commands are the proposed access path, not blanket Firestore bypasses.

## 3. Invitation and access lifecycle

Create, accept, revoke, scope change, removal and provisioning require current
online authorization. Invite validity is seven days from server creation, with
`expiresAt <= now` invalid; TTL cleanup is not an authorization check. Creation
validates active Owner, company and each warehouse in one transaction. Empty,
foreign/inactive warehouse scope, unknown role or owner invitation is invalid.
Responses use invitation IDs internally; the enrollment experience asks for a
verified Google account and invitation acceptance, never UID exchange.

`pending -> accepted` consumes the invitation once. `pending -> revoked` and
derived `expired` prohibit acceptance. Accepted/revoked/expired invitations cannot
be edited or revived; issue a new invitation with a new operation ID after any
required authorized removal. Revoke of an accepted invite is not member removal.

Acceptance checks verified recipient email/provider, active company, invitation
parent/IDs/status/expiry, inviter's current Company Owner authority, every active
warehouse and recipient membership/selected role grant in the same transaction.
It writes membership container, explicit role grant, discovery projection,
accepted marker and audit together. A recipient cannot choose a different role,
warehouse or UID. An existing active grant for the invited role conflicts; other
grants remain unchanged. Do not downgrade an Owner or widen an existing scope.
A removed role may be re-enrolled through a new valid Owner invitation with a
new revision and active membership container. Whole-membership removal requires
explicit authorized recovery before acceptance; an invitation alone cannot undo
that denial. Missing access after removal never triggers automatic promotion.

Creation retries with the same operation ID and fingerprint return the same
invitation; a changed role/email/scope with that ID conflicts. New creation with
a different ID but an existing live invitation for the same company/email/role
returns a conflict; revoke it before replacement. Implement a transactional
uniqueness guard using a server-only key over company/email/role (logical metadata
under the company); its expiry follows the invite, never a UID chosen by client.
Acceptance retries by the same UID with identical payload return the recorded
acceptance if its membership container and accepted role grant remain active with
the recorded scope/revision. A removed or changed grant/container is not restored
by replay. Another UID, conflicting payload or reused consumed invitation denies.
Concurrent accept/revoke has one committed winner; no partial membership exists.
Removal/scope change racing dispatch must be checked in the committing transaction.

Keep existing Store Manager invitation command names and branch semantics. Reuse
their verified-email, expiry and transaction patterns, but do not assert that
their current code already implements the new Google-provider, inviter-current,
payload-fingerprint or concurrency requirements. Those gaps need bounded follow-up
within the relevant task's allow-list or a coordinator scope amendment.

Staff removal targets an explicit Operations/Rider role grant, marks it removed
and updates its revision/projection without removing other grants. Whole-member
disable blocks all grants and is a distinct trusted administrative operation;
staff endpoints cannot disable an Owner container. Neither deletes historical
business evidence. Rider removal prevents new
dispatch and assigned server work; unresolved runs, proofs, collections and
remittance remain for authorized reconciliation/reassignment. Reconnect enforces
current removal; it cannot silently accept old authority or discard an outbox.

## 4. Resource ownership and read minimization

| Resource / action | Required authority and constraints |
| --- | --- |
| Company stock, supplier purchasing, warehouse setup and company finance | Company Owner; Operations may receive purchases and perform scoped fulfillment/reconciliation, but not view company-wide finance or change company ownership/staff. Company purchase costs remain company internal data. |
| Company orders, reservation, picking, packing, dispatch and return disposition | Owner or Operations in the resource warehouse; validate order company, warehouse, package and active rider scope/run assignment. Owner invitations and Operations dispatch are separate permissions. |
| Assigned rider work | Rider membership and matching active assigned run/warehouse; minimum stop destination/contact/packages, proof, quantities, return/failure and cash collection only. No price edits, order approval or assignment changes. Location sharing is explicit for an active assigned run. |
| Store retail products, stock, sales, customers, credit, staff and devices | Store identity and branch/device/delegation rules. Neither company commercial relationship nor Platform Admin grants these reads/writes. Cashier access is limited to approved POS/shift/payment/receipt operations. |
| Cross-business order and relevant delivery/payment evidence | Both `companyId` and `storeMerchantId`, plus company `warehouseId` and store `destinationBranchId` must resolve to their owners. Each party reads its own commercial slice and mutates only its own authorized facts. Scope is checked against stored linkage, not submitted destination IDs. |
| Store confirmation, receiving and summary consent | Owner confirms purchases and controls sharing. Manager may receive only with explicit receiving permission and branch scope; cashier cannot. Rider proof is separate from store receipt, warehouse return receipt, payment settlement and cash remittance. |
| Replenishment summaries | Default off; current Store Owner consent for named company, categories, purpose and branch scope. Owner can revoke; Operations sees only summaries needed for assigned customer-order work. Rider/Platform Admin gets none. Check consent on every read, stop refresh and discard cached shared summaries when revocation is observed. Commercial/audit records persist. |
| Platform administration | Application review/onboarding and explicitly authorized platform administration only. Approval creates a Store Owner under the existing flow; it cannot create a Company Owner or grant detailed retail reporting access. |

No resource mutation can write unrestricted data into the other business root.
Company order acceptance and store reconfirmation are different facts. Reserve,
shipment, receipt, return disposition and reconciliation retain immutable money,
integer centavos, stable operation IDs and explicit product/unit/price snapshots.
This document grants no new posting path or automatic financial settlement.

## 5. Typed workspace and command contracts

Use the existing Firebase Auth/App Check HTTPS transport and gateway. Keep existing
command names/response shapes for compatible store/cashier clients. New company
commands are additive; proposed names below are frozen subject to coordinator
reservation. Reuse existing correct services rather than introduce a parallel
service to satisfy a filename. Do not overload `merchantId` to mean company.

```typescript
type CompanyRole = 'companyOwner' | 'warehouseOperations' | 'rider';
type ContextRef =
  | {kind: 'company'; companyId: string; role: CompanyRole}
  | {kind: 'store'; merchantId: string}
  | {kind: 'platform'};
type VerifiedWorkspace =
  | {kind: 'company'; companyId: string; role: 'companyOwner'; roleGrantRevision: number;
      scope: {kind: 'company'}}
  | {kind: 'company'; companyId: string; role: 'warehouseOperations' | 'rider';
      roleGrantRevision: number; scope: {kind: 'warehouses'; warehouseIds: string[]}}
  | {kind: 'store'; merchantId: string; role: 'storeOwner' | 'storeManager';
      scope: {kind: 'branches'; allBranches: boolean; branchIds: string[]};
      permissions: {receiveSupplierGoods: boolean}}
  | {kind: 'platform'; role: 'platformAdmin'; scope: {kind: 'platformAdministration'}};
type WorkspacePage = {
  authorizationVersion: 1; // Proposed; coordinator reserves final value.
  workspaces: Array<VerifiedWorkspace & {
    displayName: string; membershipRevision: number;
    capabilities: string[]; // Presentation hints, never authorization evidence.
  }>;
  source: 'server'; verifiedAt: string;
  nextCursor: string | null; hasMore: boolean;
};
type MutationOutcome = {
  authorizationVersion: 1; operationId: string; context: ContextRef;
  status: 'accepted' | 'duplicate' | 'conflict' | 'blocked';
  reason?: 'accessRemoved' | 'scopeChanged' | 'legacyOwnershipUnresolved' |
    'upgradeRequired' | 'payloadConflict' | 'invitationUnavailable';
};
```

Company workspace entries include both container `membershipRevision` and required
selected `roleGrantRevision`. Return one entry per verified role grant, even for
the same company/UID; every company action selects that exact role and rechecks
container plus grant. Role switching cannot combine their scopes/capabilities.
For noncompany entries `roleGrantRevision` is omitted.
`membershipRevision` for platform is the server record's authorization revision,
not a fabricated company membership. Cashier/device bootstrap and grant responses
remain their existing typed store contracts, not human discovery workspaces.
No authorized workspace is established only after discovery terminates with zero
verified entries across all pages. An empty page with `hasMore: true` continues
discovery/loading; it must not display no-access or imply public enrollment.
Validate known discriminants, IDs, role/scope combinations, arrays and revision;
unknown/missing version or malformed context is denied, never interpreted as Owner
or platform. Legacy commands without this version follow only section 7.

| Command / entry | Request / result and ownership |
| --- | --- |
| `getAuthorizationWorkspaces` (proposed) | Human identity plus `authorizationVersion`, optional opaque `cursor`, `pageSize` 1–50 (default 25). Returns `WorkspacePage`; no caller-supplied UID/roles. Discover own projections and verify authoritative records, including platform authority separately. Company entry additionally checks Google/verified email. |
| `getCompanyWorkspace` (proposed) | Version and company context with explicit selected role; optional warehouse must be currently in that grant's scope. Returns one verified company workspace with server source/time and bounded resource references; no broad operational statistics. Owner and Operations go to Admin, Rider to Driver. |
| Company Owner provisioning (trusted CLI/tool, no public client command) | Approved company ID, verified target UID/email, stable operation ID. Check explicit provisioning authority, prevent takeover of another Owner/member, fingerprint retry, audit administrator and beneficiary. Owner retries never promote a different UID. AUTH-02 publishes operator procedure. |
| `createCompanyInvitation` (proposed) | Version, company context, stable operation ID, normalized recipient email, allowed role and warehouse IDs; returns invitation ID/status/expiry and mutation outcome. Company Owner only. |
| `listMyCompanyInvitations` (proposed) | Version, bounded pagination; token-derived verified email. Returns own still-valid invitations with company display name, role, permitted warehouse labels and expiry. Server validates company/inviter and scope; no foreign directory search. |
| `acceptCompanyInvitation` (proposed) | Version, company context selecting exactly the invited role, invitation ID and stable operation ID; recipient from token. Selection does not prove membership; acceptance checks the invite before granting that role. Returns typed workspace plus acceptance outcome after transactional checks. |
| `revokeCompanyInvitation`, `removeCompanyMember`, `updateCompanyMemberScope` (proposed) | Version, selected Company Owner context, invitation/member ID, stable operation ID; staff removal/update also requires `targetRole: warehouseOperations\|rider`; update includes intended warehouses. Cannot remove/replace Company Owner or alter other grants/container through staff endpoints. Return bounded outcome and grant revision where applicable. |
| Existing store/device/cashier/platform commands | Retain names in the [command dispatcher](../../firebase/functions/src/https/commands.ts). Preserve store/PIN contracts; revalidate role/action as in matrix. Existing broad platform `readOperationalWorkspace` reports/procurement behavior is superseded, not carried into the new workspace. |

Pagination uses stable ordering and opaque server-validated cursors bound to
subject, command, context, filters and version. Changing context invalidates a
cursor; it cannot query foreign scopes. `hasMore` and `nextCursor` agree; a
truncated list is never labeled complete. Bound invitation/projection reads as
well as response size; capacity and necessary indexes require future evidence.
Workspace display labels and capabilities disclose only authorized data. Cached
copies record local source and last server verification time; they are not server
responses with a new `verifiedAt` or proof of current authority.

Unauthenticated requests return the existing 401 authentication error. Invalid
syntax/version returns validation or safe upgrade-required failure. Foreign,
unknown or inaccessible resource IDs use the same generic permission-denied
response, without existence/recipient disclosure. Invitation expiry/revocation
details are available only to the verified recipient or authorized Owner.
Conflicts are distinct from retryable infrastructure failures; safe reasons retain
the current structured HTTPS error behavior. Network/503/App Check verification
outage does not fabricate success or establish revocation. Current authoritative
denial blocks privileged actions and clears cached authority, preserving facts.

## 6. Actor/action denial matrix and observable traces

All permissions require the active matching context and checks above. `Scoped`
means assigned warehouse/branch, specific grant or run; `Denied` includes attempts
from a different context even when the same UID holds another role.

| Action | Company Owner | Operations | Rider | Store Owner | Store Manager | Cashier | Platform Admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Company invitations / staff scope / removal | Allowed | Denied | Denied | Denied | Denied | Denied | Denied |
| Company warehouse setup / purchasing commitment | Allowed | Denied | Denied | Denied | Denied | Denied | Denied |
| Company order acceptance / purchase receipt / reserve / pick / pack / dispatch / return disposition | Allowed | Scoped | Denied | Denied | Denied | Denied | Denied |
| Assigned stop proof / progress / cash collection / voluntary location | Denied as rider action | Denied as rider action | Scoped | Denied | Denied | Denied | Denied |
| Company-wide finance / wholesale oversight | Allowed | Denied | Denied | Denied | Denied | Denied | Denied |
| Warehouse collection/remittance reconciliation | Allowed | Scoped | Denied (reports own collection only) | Denied | Denied | Denied | Denied |
| Store branches / Manager roles / sharing consent | Denied | Denied | Denied | Allowed | Denied | Denied | Denied |
| Store cashier/device management | Denied | Denied | Denied | Allowed | Scoped existing delegation | Denied | Denied |
| Store purchase confirmation | Denied | Denied | Denied | Allowed | Denied | Denied | Denied |
| Store supplier receipt | Denied | Denied | Denied | Allowed | Scoped explicit receiving | Denied | Denied |
| POS checkout / payments / receipt / shift | Denied as POS session | Denied | Denied | Scoped POS session | Scoped POS session | Scoped POS session | Denied |
| Detailed store sales/customer/credit/staff reads | Denied | Denied | Denied | Allowed | Scoped existing permission | Scoped approved POS need only | Denied |
| Own commercial order / relevant delivery evidence | Company records | Scoped company records | Assigned minimum | Own store records | Scoped store records | Denied | Denied |
| Store-shared replenishment summaries | Current consent | Current consent + scoped need | Denied | Own summaries | Scoped own records; cannot consent | Denied | Denied |
| Merchant onboarding review | Denied | Denied | Denied | Own application status only | Denied | Denied | Allowed |
| Public/self Company Owner promotion / role union | Denied | Denied | Denied | Denied | Denied | Denied | Denied |

Owner/Operations monitoring is separate from impersonating a rider or cashier.
If an Owner legitimately also has POS or Rider authority, switch to that verified
session and attribute its actor; do not use Owner credentials as another worker.

| Canonical actor | Sign-in and allowed trace | Denial trace | Reconnect trace / evidence status |
| --- | --- | --- | --- |
| Company Owner | Google plus trusted provision, select company, invite scoped Operations. | Existing merchant Owner or admin-only token attempts company entry: deny. | Recheck active company/member; cached workspace never authorizes invitation. New runtime and Development identity trace pending AUTH-02. |
| Operations | Google, accept own Owner invite, select assigned warehouse, dispatch active in-scope rider. | Invite staff, foreign warehouse, unrelated store records/company finance: deny. | Removed/reduced scope blocks new dispatch; retain pending observations. New runtime trace pending AUTH-05/AUTH-11. |
| Rider | Google in Driver, accept own invite, receive assigned run, durably record proof/collection. | Unassigned run, changed prices, dispatch or store receipt: deny. | Same-boot trusted offline assigned work only; server rechecks current membership/run, blocks rejected evidence without deleting it. Current Driver cache/assignment checks are reuse evidence, not company acceptance. |
| Store Owner | Existing Google approval/membership, select store, confirm order or activate authorized POS device. | Company dispatch/invitations or another store: deny. | Revalidate own membership/device; preserve local facts and block cloud actions after removal. Existing store implementation is reuse evidence; new cross-business flow pending. |
| Store Manager | Existing Google invitation; scoped device/cashier operation or explicitly granted receiving. | Manager invitations, ownership, purchase confirmation, consent or foreign branch: deny. | Scope change applies on current check; receiving permission absent is denial. Existing branch invitation tests inspected, not rerun. |
| Cashier | Registered device, online first temporary-PIN change, later PIN checkout on assigned branch. | Google/company enrollment, grant roles, consent, store purchasing or foreign device/branch: deny. | Seven-day same-boot recovery; current device/cashier/grant check on replay. Suspension/PIN change/reassignment/revocation blocks work without destroying durable receipts. Existing source evidence; live verification pending. |
| Platform Admin | Google plus claim and active record, review merchant application in separate platform workspace. | Retail reports, company operational mutations or self Company Owner grant: deny. | Refresh active admin record; loss of claim/record closes platform workspace. Current report reader violates target denial; closure pending AUTH-13. |

No visible screen is added by AUTH-01. Downstream entry must expose loading,
no-access/empty, invitation pending/expired/revoked, denied, validation, failure,
retry, online-required/offline-pending and success states. Keep chosen business and
branch/warehouse visible, preserve valid input on retry and prevent duplicates.
Switching identity/context dismisses privileged routes and invalidates stale
requests/cursors/caches, while keeping each context's durable work isolated.
No-access recovery is sign-in/change account/refresh/contact authorized Owner;
it never asks for internal UIDs or offers automatic role elevation.

## 7. Legacy mapping, replay and offline durability

| Legacy evidence | Explicit compatibility interpretation |
| --- | --- |
| Active `merchants/{merchantId}` with existing Owner | Existing store business and Store Owner only; preserve ID, branches, retail records and wire roles. Never bootstrap company ownership from it. |
| Existing merchant Manager/allBranches/branchIds | Store Manager scope only, retaining explicit all-branches semantics. Never Warehouse Operations or consent/purchase confirmation. |
| `sarisupplyAdmin` and active `platformAdmins/{uid}` | Platform administration only. Existing broad reports/procurement reads must close; no grandfathered blanket reads. |
| Existing merchant warehouse, procurement, restock, package, driver or run | Historical legacy merchant-scoped facts; company/store ownership is unresolved unless an exact reviewed resource binding says otherwise. Existing branch destination does not become an independent-store order. No automatic owner/manager/rider promotion or company linkage. |
| `driverWorkspaces/{uid}/assignments/{merchantId}` | Discovery hint only; reread current legacy driver/run or newly explicit company membership. A legacy assignment cannot become company employment. |
| Device tokens, cashier credentials/grants and pending store checkout | Existing store/device/cashier binding; retain IDs, PIN policy, payloads and result records. No company conversion, reactivation or local data reset. |

Old clients retain compatible command names, response shapes, stable IDs and
historical store paths. Absent new version is permitted only on a known legacy
command with its explicit mapping and current authorization. Unsupported version,
unknown role/context or contradictory legacy/company IDs fail closed; never fall
back to Owner. New company commands require the reserved version and explicit
company context. Legacy command families that would dispatch/enroll company work
or expose broad platform reports return safe upgrade/ownership-resolution denial;
they cannot preserve unsafe authority for compatibility. Company-side adaptation
requires reviewed bindings and current company roles, not an automatic forwarding
of legacy merchant Owner credentials.

Rollout needs a server-first compatibility gate before exposing company entry:
inventory existing command families, bind proven legacy ownership explicitly,
retain safe store commands, disable unsafe legacy mutations/reads and document
operator recovery. AUTH-13 closes broad platform reads; downstream business tasks
and RELEASE own legacy resource adapters/migration rehearsal. AUTH-01 does not
claim these controls already run. An unresolved mixed root may stay historical
and read-only to its legitimately authorized owner, without cross-business reads.
Accepted legacy records remain unchanged; explicit future compensating/mapping
records explain ownership rather than rewriting historical money or destinations.

For each new mutation, generate a stable operation ID before submission; persist
the immutable attempted command/payload, context, authenticated actor binding and
canonical request fingerprint before network upload. Server idempotency key is
bound to environment, command/action, business owner, actor/selected role and operation ID;
store pending operations retain their existing IDs/key interpretation. A reviewed
legacy adapter resolves context through binding metadata outside the attempted
payload: never edit queued JSON, mint a replacement operation ID, reuse an ID in
a new business or recalculate historical finance to make migration succeed.

The server atomically stores result, effects and audit. Same ID/same fingerprint
returns the recorded accepted result as duplicate with no extra business/audit
effect; same ID/different fingerprint conflicts. Missing current membership,
device/cashier grant, resource assignment, consent or resolved ownership produces
blocked evidence, no business mutation. Previously accepted results remain
immutable; current authorization is still needed to disclose them, so a removed
actor cannot use replay to retrieve another context's data. If current access
prevents acknowledgement, retain the pending operation for authorized recovery;
do not invent a duplicate receipt or promise a new revoked-user status endpoint.
Existing result-only `runIdempotent` is not proof of fingerprint protection.

Only explicit durable offline retail/assigned-delivery intents are allowed.
Company provisioning, invitations, scope changes, dispatch, purchase acceptance,
consent changes and privileged cloud financial approval/acceptance/reconciliation
require online authority. Approved local cashier cash/manual-QR tender recording
and durable checkout remain permitted offline under existing grant/clock policy;
local success and pending cloud synchronization stay distinct. A draft or
pending intent is never a server-accepted order, reservation, membership, dispatch
or payment. Local business records, stock/financial changes and outbox entries commit
atomically. Timeout, partial acknowledgement, unknown response and quota exhaustion
retain unacknowledged entries; permanent denials become blocked for recovery rather
than infinite retries. A role switch/reconnect/sign-out cannot delete financial
facts, unresolved audit evidence or durable pending work.

Keep the existing seven-day maximum trusted same-boot authorization window,
monotonic boot/elapsed-clock evidence and wall-clock defenses. Reboot, missing
clock, expired window or observed authoritative revocation requires online
recovery, not a new offline membership grant. Clear stale authority/credential
caches after denial; preserve SQLite ledger/outbox/proof/security queues separately.
Current server checks apply before replay; historical assignment proof is not
currently implemented for rejected offline PIN reports or revoked work. Do not
silently bypass current access to clear a queue; explicit recovery is a later gate.

## 8. Audit attribution

Keep old audit records and actor IDs intact. New company events live beneath the
company audit root; new store events keep the merchant audit root. Additive event
fields are `authorizationVersion`, `context`, `authSubjectUid`, `actorType`,
`actorId`, selected `role`, `membershipRevision` and company `roleGrantRevision`
(when applicable), `warehouseId`/`branchId`,
`deviceId`, `cashierId`, `sessionId`/`grantId`, `operationId`, `requestFingerprint`,
`action`, typed target owner/ID, `outcome`, and server `createdAt`. Fields are
required when that actor/action uses them and otherwise omitted, never guessed.

Actor type describes human/device/cashier/platform administrator, while role
describes the selected business permission. A cashier event attributes cashier
ID plus authenticated device subject and verified grant/session; it cannot claim
the approving Store Owner performed checkout. Approval and beneficiary are
separate: provisioning/invitation events record trusted issuer and recipient;
refund approval and cashier execution retain both identities. Derive attribution
from verified records, not supplied role/display labels. Cross-business events
carry both party references but expose only each authorized party's audit slice.

Record accepted mutations and audits atomically once per operation. Rejected
attempt logging may use a separate bounded security event with safe reason and
server-derived subject/context, without a partial business write or duplicate
accepted audit. Never log PINs, grant secrets, tokens, server credentials or raw
sensitive request payloads. Historical business/audit retention remains governed
by the existing retention/archive contract; access removal does not erase it.

## 9. Source evidence and downstream wiring

| Inspected implementation | Reuse / gap established by inspection |
| --- | --- |
| [Authorization service](../../firebase/functions/src/common/authz.ts), `requireHuman`, `requirePlatformAdmin`, `requireActiveMembership`, `requireBranchAccess`, `requireActiveDevice` | Distinct human/device authentication, current merchant membership and branch/device checks; Owner/Manager only. Company policy and verified provider checks are absent here. |
| [Store membership service](../../firebase/functions/src/membership/membership-service.ts), invitation create/list/accept/revoke and Manager scope/removal | Verified lowercase token email, seven-day expiry, transactional acceptance and projections; scope checks reusable. Accepted replay and key-only create do not establish all new revision/fingerprint/inviter/provider guarantees. |
| [Membership test source](../../firebase/functions/test/membership/membership-service.emulator.test.ts) | Source asserts Owner-only mutations, verified-email single acceptance, expiry/revocation/inactive branch/conflicting membership and removal. Inspected only; no AUTH-01 emulator execution or company-actor coverage claim. |
| [Device service](../../firebase/functions/src/device/device-service.ts), [cashier service](../../firebase/functions/src/cashier/cashier-service.ts), [cashier grants](../../firebase/functions/src/checkout/cashier-grants.ts) | Existing active device, cashier assignment, credential/grant/secret and occurrence-time checks; preserve separate subject and cashier. |
| [Checkout service](../../firebase/functions/src/checkout/checkout-service.ts), `recordCheckoutOperation` | Current grant check before replay, canonical intent fingerprint, immutable accepted result and duplicate/blocked responses; reuse semantics without copying receipt IDs or historical facts. |
| [Idempotency helper](../../firebase/functions/src/common/idempotency.ts), [audit writer](../../firebase/functions/src/common/audit.ts) | Transactional result caching and merchant audit writing; helper does not compare attempted payloads and audit currently requires merchant context. New additive company fields/owner root need downstream wiring. |
| [Delivery service](../../firebase/functions/src/delivery/delivery-service.ts), `manageDeliveries`, `getDriverWorkspaces` | Current merchant Owner dispatch; active driver and warehouse/run checks; merchant rider enrollment/projections are not company invitations. |
| [Procurement service](../../firebase/functions/src/procurement/procurement-service.ts), `manageRestockProposals` | Warehouse and destination branches share merchant root; no independent-store commercial binding. |
| [Operational reads](../../firebase/functions/src/management/operations-read-service.ts), `readOperationalWorkspace` | Platform Admin can read active merchant procurement/reports today. Target denies; AUTH-13 closes this gap. |
| [HTTPS handler](../../firebase/functions/src/https/handler.ts), [dispatcher](../../firebase/functions/src/https/commands.ts), [rules](../../firebase/firestore.rules) | Verified identity/App Check transport, shared command registry and deny-by-default writes; new company registries/rules are not implemented by this contract. |
| [Admin gate](../../apps/admin/lib/app/admin_app_gate.dart), [POS gate](../../apps/pos/lib/app/pos_app_gate.dart), [Driver gate](../../apps/driver/lib/app/driver_app_gate.dart) | Current platform Admin, store/PIN and legacy Driver entry. Driver cache checks same-boot seven-day access and clears denied assignments; company workspace separation remains work. |
| [Offline credential policy](../../packages/sarisupply_auth/lib/src/offline/offline_credential_policy.dart), [membership adapter](../../packages/sarisupply_firebase/lib/src/functions/membership_functions.dart) | Same-boot monotonic/clock validation and personal store membership reads; retain Dart domain/Firebase separation. |

Coordinator owns final version allocation, `https/commands.ts`, package exports,
app gates and schema/local migration registry allocation. AUTH-02 establishes
company identity/models/repository and entry; AUTH-03/04 separate platform/store
entry; AUTH-05/06 implement scoped company invitations; AUTH-07–12 preserve store
credentials and enforce removals/recovery; AUTH-13 closes broad reads; AUTH-14
freezes navigation states; AUTH-90 independently integrates authorization.
SETUP-00 and later contracts consume these owner/context references without
redefining authorization. Company staff invitations also wait for real warehouse
setup prerequisites in the task guide. No dependent task is started by AUTH-01.

Independent review by `/root/auth01_review` (`gpt-6.1-sol`, reasoning `high`)
approved the corrected contract and handoff with no unresolved findings. The
initial multi-role schema finding was repaired with separate selected role grants.
This is documentation acceptance only; proposed versions/paths still require
coordinator reservation and integration.

Development identity/backend traces, schema/index feasibility, old-client mixed
data rehearsal, removal/offline replay, concurrency, live App Check/provider
verification and phone role switching remain pending downstream acceptance gates.
No hardware, live credential, Production configuration or deployed company schema
was accessed for this document. This contract and existing local test evidence
cannot establish production readiness.
