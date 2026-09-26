# SariSupply Firebase Identity, Tenant, Device, and Cashier Authentication Design

**Date:** 2026-09-26  
**Status:** Approved design, ready for implementation planning  
**Scope:** Firebase identity, merchant onboarding and approval, multi-merchant membership, branch authorization, POS device trust, cashier PIN authentication, auditability, offline credential behavior, and development/production environment separation.

## 1. Purpose

This milestone establishes the production security and tenancy foundation for SariSupply before sales, inventory, warehouse, delivery, and payment workflows are built.

The design must support:

- Flutter-only user-facing applications.
- Firebase as the cloud backend.
- Google Sign-In for Owners, Managers, and SariSupply Admins.
- Self-registration of merchant applicants followed by SariSupply approval.
- Limited merchant setup while approval is pending.
- Multi-merchant Google identities.
- Multi-branch merchants with branch-scoped Managers.
- Merchant-level cashier identities with branch assignments.
- Direct Owner/Manager POS device activation.
- Secure cashier PIN authentication with offline access.
- Seven-day offline cashier credential validity.
- Strong auditability across merchant, branch, device, user, cashier, session, and later shift.
- Development and Production Firebase environments only for V1.
- A structure that can add staging later without redesigning the system.

This milestone does not implement the operational sales, inventory, warehouse, delivery, payment, or reporting modules. It establishes the security boundaries those modules will rely on.

## 2. Approved Product Decisions

The following decisions are authoritative for this milestone.

### 2.1 Firebase environments

SariSupply will initially use exactly two Firebase projects:

- Development
- Production

Development and Production do not share users, Firestore data, Storage, Functions, credentials, or application registrations.

### 2.2 Merchant onboarding

Merchant onboarding uses self-registration with SariSupply approval.

A prospective Owner:

1. Signs in with Google.
2. Creates a merchant application.
3. Completes the business profile.
4. Creates the first branch draft.
5. Submits the application.
6. Waits for SariSupply review.

While pending, the Owner may complete limited setup but cannot use operational POS functions.

### 2.3 Pending merchant capabilities

A pending applicant may:

- complete or update the business profile;
- complete the first branch draft;
- view application status.

The applicant may not:

- activate POS devices;
- create cashiers;
- perform inventory operations;
- record sales;
- use customer credit;
- place SariSupply restock orders.

### 2.4 Merchant approval

When a SariSupply Admin approves a valid application, the backend automatically:

- creates the Merchant;
- creates the first active Branch;
- creates the Owner membership;
- creates the user-to-merchant reference;
- records the approval result on the application;
- writes an audit event.

Approval does not automatically trust a POS device.

### 2.5 Manager onboarding

Only the Owner may invite, remove, or change Manager access.

Manager onboarding is invitation-based:

1. Owner enters the Manager's Google-account email.
2. Owner assigns branch scope.
3. Backend creates a single-use, expiring invitation.
4. Recipient signs in with the matching Google account.
5. Recipient accepts the invitation.
6. Backend creates the Manager membership.

Managers cannot create or elevate other Managers.

### 2.6 Manager branch scope

Managers are branch-scoped by default.

A Manager may have:

- one assigned branch;
- several selected branches; or
- explicit all-branches access.

An all-branches Manager is also authorized for branches created later while that all-branches assignment remains active.

### 2.7 Branch administration

Only the Owner may create or deactivate branches.

Managers may edit permitted operational details for branches inside their scope, such as:

- store contact details;
- operating hours;
- device display names;
- cashier assignments where allowed.

Managers cannot alter merchant ownership or structural authorization boundaries.

### 2.8 Cashier identity

Cashiers use merchant-level identities rather than branch-specific duplicate accounts.

A cashier record may be assigned to one or more branches. The same cashier keeps one identity and one audit history when temporarily working at another authorized branch.

Cashiers do not require Google accounts and are not represented as normal Firebase Auth users.

### 2.9 Cashier PIN lifecycle

The approved cashier credential flow is:

1. Owner or authorized Manager creates the cashier.
2. A temporary PIN is issued.
3. First login requires internet.
4. Cashier must change the temporary PIN before entering the normal POS.
5. Cashier may later change their own PIN while authenticated.
6. Owner or authorized Manager may reset a forgotten PIN.
7. Every PIN reset and relevant credential event is audited.

Plaintext PINs are never stored.

### 2.10 POS device activation

A new POS tablet must be explicitly activated.

Activation flow:

1. Owner or authorized Manager signs in with Google on the device.
2. User selects a merchant they are authorized to operate.
3. User selects an allowed branch.
4. User gives the device a display name.
5. Backend validates authorization.
6. Backend registers the device and provisions its trusted device identity.

After activation, normal cashier POS use does not require the Owner or Manager to remain signed in.

### 2.11 Offline cashier login

Offline cashier login is allowed for at most seven days since the device's last successful server-backed credential refresh.

After the seven-day validity window expires, the device must reconnect before starting another cashier session.

Revocations, branch assignment changes, cashier suspensions, and PIN changes take effect locally after the next successful credential refresh.

### 2.12 Multi-merchant Google identities

One Google/Firebase identity may belong to multiple merchants simultaneously.

Examples:

- Owner of Merchant A;
- Manager of Merchant B;
- Owner of Merchant C.

Permissions are always resolved using the active merchant context. The client shows a merchant selector only when the user has more than one active merchant membership.

### 2.13 SariSupply Admin identity

SariSupply Admins use:

- Google Sign-In;
- explicit pre-authorization;
- a global admin custom claim where useful;
- a server-side active admin record for sensitive authorization.

Signing in with Google alone never grants SariSupply Admin access.

## 3. Architecture

### 3.1 Client applications

All user-facing clients remain Flutter:

- SariSupply POS — Flutter Android/tablet
- SariSupply Driver — Flutter Android
- SariSupply Admin / Operations — Flutter Web

The Driver app is not materially changed by this milestone, but environment and shared identity foundations must remain compatible with it.

### 3.2 Backend

The cloud backend uses:

- Firebase Authentication;
- Cloud Firestore;
- Cloud Functions;
- Firebase Storage;
- Firebase Cloud Messaging;
- Firebase App Check;
- Firebase Crashlytics;
- Google Secret Manager for backend secrets.

Drift/SQLite is the durable offline data store for the POS.

### 3.3 Authorization approach

Merchant and branch permissions are stored in Firestore authorization records and enforced by trusted backend logic.

Firebase custom claims are intentionally kept small. They are not used to encode normal merchant membership or branch scope because:

- one user may belong to many merchants;
- branch assignments can change;
- claims become stale until token refresh;
- claims have size constraints.

A small global custom claim such as `sarisupplyAdmin = true` is acceptable for SariSupply platform administration, but sensitive operations still verify an active server-side admin record.

## 4. Principal Model

SariSupply has two Firebase principal categories.

### 4.1 Human principal

Human principals authenticate with Google through Firebase Auth.

Used for:

- Owner;
- Manager;
- SariSupply Admin.

### 4.2 POS device principal

A registered POS tablet receives its own Firebase device identity through a protected activation flow.

The device identity is independent from the Owner or Manager who activated it.

This prevents normal POS synchronization from running under an Owner's personal Firebase identity.

A device token carries only minimum identity information, such as:

- principal type;
- device ID.

Current merchant, branch, and active/revoked status are resolved server-side from authoritative device records.

### 4.3 Operational actor attribution

The cloud principal and the business actor are separate concepts.

For a cashier sale:

- cloud principal: registered POS device;
- business actor: cashier;
- tenant context: merchant and branch;
- operation context: session and later shift.

Every protected operational record must be attributable to concrete actor context.

## 5. Firestore Data Model

The merchant is the primary tenancy and security boundary.

Conceptual structure:

```text
users/
  {uid}/
    merchantRefs/
      {merchantId}

merchantApplications/
  {applicationId}

merchants/
  {merchantId}/
    memberships/
      {uid}
    branches/
      {branchId}
    managerInvites/
      {inviteId}
    cashiers/
      {cashierId}
    cashierCredentials/
      {cashierId}
    devices/
      {deviceId}
    auditEvents/
      {eventId}
```

Future operational modules will fit beneath the merchant boundary, for example:

```text
merchants/{merchantId}/
  products/
  customers/
  sales/
  shifts/
  inventoryMovements/
  stockCounts/
  transfers/
  restockOrders/
  deliveries/
  promotions/
```

Those operational collections are outside this milestone.

## 6. User Profile and Merchant References

`users/{uid}` contains global identity/profile information only, such as:

- uid;
- display name;
- email;
- photo URL;
- created timestamp;
- last sign-in timestamp.

Global user documents do not hold authoritative merchant role assignments.

A lightweight projection at:

```text
users/{uid}/merchantRefs/{merchantId}
```

supports fast discovery of accessible merchants.

Authoritative merchant permissions live at:

```text
merchants/{merchantId}/memberships/{uid}
```

## 7. Merchant Membership Model

A membership document conceptually contains:

- userId;
- merchantId;
- role;
- status;
- branch access;
- createdAt;
- createdBy;
- updatedAt.

Supported roles in this milestone:

- owner;
- manager.

Supported statuses:

- active;
- suspended;
- removed.

Branch access contains:

- `allBranches: true|false`;
- `branchIds: [...]`.

Owner membership is always all-branches.

Manager membership may be selected-branches or all-branches.

## 8. Merchant Application State Machine

Application states are explicit:

```text
draft
  -> submitted
  -> pending_review
      -> approved
      -> rejected

rejected
  -> resubmitted
  -> pending_review
```

A merchant application conceptually contains:

- applicantUid;
- status;
- businessProfile;
- firstBranchDraft;
- submittedAt;
- reviewedAt;
- reviewedBy;
- reviewNotes;
- approvedMerchantId.

Application approval is a protected, idempotent backend operation.

Repeated approval requests for the same already-approved application return the established result and do not create duplicate merchants.

## 9. Branch Model

A branch document conceptually contains:

- name;
- code;
- address;
- contact details;
- operating hours;
- status;
- createdAt;
- createdBy;
- updatedAt.

Branch status includes:

- active;
- inactive.

Only the Owner may create or deactivate branches.

Managers may modify approved operational fields only when the branch is in their assigned scope.

## 10. Manager Invitation Model

A Manager invitation conceptually contains:

- email;
- branch access;
- status;
- expiresAt;
- createdAt;
- createdBy;
- acceptedAt;
- acceptedBy;
- revokedAt.

Manager invitations are:

- email-bound;
- single-use;
- expiring;
- revocable before acceptance;
- server validated.

The recipient does not query all invitation documents directly by arbitrary email.

The client calls a protected backend endpoint such as `listMyInvitations`. The backend reads the verified Firebase email from the signed-in user and returns only eligible invitations.

Invite acceptance validates:

- invitation still exists;
- status is active;
- invitation is not expired;
- invitation is not revoked;
- verified signed-in email matches;
- merchant remains valid;
- requested branch scope remains valid;
- membership does not create an invalid duplicate.

Acceptance creates the membership and marks the invite accepted as one trusted operation.

## 11. Cashier Model

The non-sensitive cashier document contains:

- display name;
- employee code;
- assigned branch IDs;
- status;
- mustChangePin;
- createdAt;
- updatedAt.

Cashier status includes:

- active;
- suspended.

Only cashiers assigned to the POS device's current branch may appear as usable cashiers on that device.

## 12. Cashier Credential Security

Cashier credential material is stored separately from normal cashier profile data.

Conceptual path:

```text
merchants/{merchantId}/cashierCredentials/{cashierId}
```

Normal Flutter clients are never permitted to read or write this collection directly.

Credential storage uses:

- a slow password/PIN KDF;
- a unique salt;
- a server-side secret pepper stored in Secret Manager;
- credential version metadata.

The system never stores a plaintext PIN or a simple unsalted hash such as `SHA256(pin)`.

Credential creation, change, reset, and validation are protected backend operations.

## 13. Offline Cashier Credential Enrollment

A cashier becomes offline-capable on a particular POS tablet only after successful online authentication on that device.

Enrollment flow:

1. Cashier enters PIN.
2. Backend validates PIN.
3. Backend confirms cashier is active and assigned to the current branch.
4. Device creates or receives the material needed for a device-specific local verifier.
5. Local verifier is protected with Android secure storage / Keystore.
6. Offline login becomes available for that cashier on that specific device.

A temporary PIN is not valid for ordinary offline operation.

First-use temporary PIN change requires connectivity. Offline enrollment occurs only after the permanent PIN is confirmed by the backend.

## 14. Seven-Day Offline Credential Window

The offline credential bundle includes trusted server-backed issuance and expiry metadata.

Conceptually:

- credentialBundleIssuedAt;
- credentialBundleExpiresAt.

Offline login is allowed only when the current device has a valid non-expired credential bundle.

The seven-day window is not extended solely by client-side timestamps.

If the device clock appears materially manipulated or invalid, the POS requires an online refresh instead of extending offline access.

## 15. PIN Retry Protection

Cashier PINs are low-entropy secrets and require rate limiting.

Online verification uses server-side throttling.

Offline verification uses local controls such as:

- failed-attempt counters;
- short cooldown after repeated failures;
- increasing delay for continued failures;
- temporary local lockout.

The POS does not permanently disable a cashier solely because of local failed attempts.

Repeated failures are emitted as security/audit events when connectivity returns.

## 16. POS Device Model

A device document conceptually contains:

- deviceId;
- branchId;
- displayName;
- platform;
- appVersion;
- status;
- registeredAt;
- registeredBy;
- lastSeenAt;
- lastCredentialRefreshAt;
- revokedAt;
- revokedBy.

Device status includes:

- active;
- revoked.

A device remains bound to one merchant and one branch at a time unless a future explicitly designed reassignment workflow changes that rule.

Manager device activation is permitted only within the Manager's branch scope.

## 17. POS Human and Device Firebase Contexts

The POS must preserve the device principal while allowing temporary elevated human authorization.

The design therefore separates two Firebase contexts conceptually:

### Device context

Used continuously for:

- synchronization;
- device configuration;
- POS cloud operations.

### Human context

Used temporarily for:

- initial device activation;
- Owner authorization;
- Manager authorization;
- PIN resets;
- protected settings.

Human login must not overwrite or silently replace the persistent device identity used for POS synchronization.

Implementation may use separate Firebase app/auth contexts or an equivalent isolation mechanism that preserves this invariant.

## 18. Protected Backend Operations

Sensitive actions run through Cloud Functions rather than direct client Firestore writes.

Examples include:

- merchant approval;
- merchant rejection;
- Manager invitation creation;
- Manager invitation acceptance;
- Manager removal;
- branch creation;
- branch deactivation;
- device activation;
- device revocation;
- cashier creation;
- cashier suspension;
- cashier PIN change;
- cashier PIN reset;
- cashier credential refresh.

Functions validate authorization against current Firestore state at execution time.

Firestore Security Rules remain a defense-in-depth boundary rather than the only authorization layer.

## 19. Authorization Rules

Default policy is deny-by-default.

Conceptually:

- unauthenticated users have no merchant access;
- authenticated humans may access only merchants with valid memberships;
- Owners have merchant-wide authority except SariSupply-only platform actions;
- Managers are limited to assigned branch scope and allowed operations;
- cashiers are not normal Firebase human principals;
- registered POS devices are restricted to their own trusted device/merchant/branch operational interfaces;
- SariSupply Admin actions require explicit active admin authorization.

A client-provided role, merchant ID, branch ID, cashier ID, or device ID is never trusted by itself.

The backend resolves and verifies relationships from authoritative records.

## 20. Audit Context

Every security-sensitive and later operational action must carry enough context to answer who did what, where, and from which device.

Relevant fields include:

- merchantId;
- branchId;
- deviceId;
- firebaseUserId when applicable;
- cashierId when applicable;
- sessionId;
- shiftId once shift management exists;
- timestamp.

Audit events conceptually contain:

- eventType;
- actor;
- merchantId;
- branchId;
- targetType;
- targetId;
- timestamp;
- metadata.

Examples:

- merchant.approved;
- manager.invited;
- manager.removed;
- branch.created;
- branch.deactivated;
- device.registered;
- device.revoked;
- cashier.created;
- cashier.pin_reset;
- cashier.suspended.

Normal clients may not edit or delete audit history.

## 21. Revocation Hierarchy

Server authority follows this hierarchy:

```text
Merchant suspended
  -> merchant operational access blocked

Branch deactivated
  -> branch operational access blocked

Device revoked
  -> trusted device cloud access blocked

Manager removed
  -> merchant membership access blocked

Cashier suspended
  -> future cashier sessions blocked after refresh
```

Offline devices may temporarily operate on previously valid local state within the approved offline window. That limitation is explicit and auditable.

## 22. Offline Device Revocation

If a device is revoked while offline, the tablet cannot know immediately.

When it reconnects:

1. backend recognizes the device as revoked;
2. normal synchronization is blocked;
3. unsynced local operations remain intact;
4. POS enters a controlled revoked state;
5. Owner/SariSupply recovery is required to decide how legitimate unsynced operations should be reconciled.

The application must never silently delete unsynced local sales solely because the device was revoked.

## 23. Offline Cashier Revocation

If a cashier is suspended while a valid device is offline, the cashier may continue authenticating until either:

- the device refreshes credentials and receives the suspension; or
- the seven-day credential bundle expires.

Offline actions remain attributable to the cashier, branch, device, and timestamp.

After successful refresh, a suspended cashier cannot start a new session.

## 24. Failure and Sync Philosophy

The POS distinguishes local durability from cloud synchronization.

For ordinary supported offline operations:

```text
LOCAL_SUCCESS
= operation is safely committed to Drift/SQLite

SYNCED
= cloud has acknowledged the operation
```

A temporary network failure must not make the POS claim that a locally committed cash sale failed.

The user interface presents actionable states such as:

- saved offline, pending sync;
- reconnect required;
- device no longer authorized;
- offline credential period expired.

Raw Firebase exceptions are retained for diagnostics but are not shown directly to cashiers.

## 25. Local Transaction Integrity

Related local writes must commit atomically in Drift/SQLite.

For a future sale, the local transaction will include all required records such as:

- sale;
- sale lines;
- payment;
- inventory movements;
- audit metadata;
- outbox operation.

The POS must not allow partial local completion such as a sale without corresponding inventory movement or vice versa.

## 26. Outbox and Idempotency

Every syncable operation receives an immutable globally unique operation ID before cloud submission.

Recommended IDs may use ULID or another sortable globally unique identifier.

The outbox tracks states such as:

- pending;
- syncing;
- synced;
- retryable_error;
- blocked.

Transient errors such as network loss or timeout are retryable.

Permanent authorization failures such as revoked device, deactivated branch, suspended merchant, or invalid actor become blocked and do not retry indefinitely.

The backend stores processed operation IDs or equivalent idempotency state.

Repeating the same operation request returns the established result and must not duplicate the business event.

Idempotency applies later to:

- sale completion;
- refunds;
- voids;
- inventory movements;
- stock adjustments;
- transfers;
- restock orders;
- delivery confirmations;
- payment confirmations.

## 27. Cloud Consistency and Conflict Rules

Important operational data is event/ledger oriented rather than blindly overwritten.

Examples:

- sales are never overwritten;
- inventory movements are immutable evidence;
- payments are never overwritten;
- audit events are immutable;
- server merchant status wins over stale client state;
- server branch status wins over stale client state;
- server device status wins over stale client state;
- newer valid credential versions win over stale credentials.

Last-write-wins is acceptable only for selected non-critical profile/configuration fields where the product explicitly allows it.

A stale POS may never reactivate a revoked device by synchronizing an older cached record.

## 28. Development and Production Environment Layout

There are two independent Firebase projects:

```text
SariSupply Development
  Auth
  Firestore
  Functions
  Storage
  FCM
  App Check
  Crashlytics
  POS Android app
  Driver Android app
  Admin Web app

SariSupply Production
  Auth
  Firestore
  Functions
  Storage
  FCM
  App Check
  Crashlytics
  POS Android app
  Driver Android app
  Admin Web app
```

Nothing sensitive or authoritative is shared between the two environments.

The codebase supports explicit `dev` and `prod` configuration.

Android uses build flavors so development and production apps can coexist on a development device.

The Admin Flutter Web build is also environment-specific.

Staging is deliberately not created now, but environment selection must be designed so adding a third configuration later does not require architectural restructuring.

## 29. Secret Management

Firebase client configuration is not treated as a private backend secret.

True backend secrets must not be committed to the Flutter repository.

Examples include:

- cashier credential pepper;
- future payment provider secrets;
- API signing keys;
- sensitive service credentials.

These belong in Google Secret Manager or equivalent managed backend configuration.

The existing repository policy must continue to exclude environment and platform credential files such as production service-account credentials and generated platform service files where appropriate.

## 30. App Check and Abuse Protection

App Check should be enabled for supported production clients once the Firebase environment wiring is stable.

App Check complements authentication but does not replace authorization.

Sensitive callable/server endpoints must additionally enforce:

- authenticated principal;
- active device or human membership;
- merchant and branch scope;
- rate limiting where relevant;
- idempotency where relevant.

## 31. Error Handling Requirements

User-facing errors are domain-specific and actionable.

Examples:

```text
"This device is no longer authorized. Ask the store owner to reactivate it."

"You're offline. The transaction has been saved and will sync automatically."

"Your offline login period has expired. Connect this device to the internet to continue."
```

Technical exception details remain available through logging and Crashlytics.

Local business data is never discarded simply because cloud synchronization fails.

## 32. Testing Strategy

This milestone requires tests at multiple boundaries.

### 32.1 Pure Dart tests

Test:

- merchant membership decisions;
- branch scope resolution;
- application state transitions;
- cashier status decisions;
- seven-day credential expiry;
- PIN retry/lockout state;
- device state transitions;
- idempotency helper behavior where implemented in shared code.

### 32.2 Firebase emulator tests

Test:

- Firestore Security Rules;
- Cloud Function authorization;
- merchant approval;
- merchant rejection/resubmission;
- Manager invitation;
- invitation acceptance;
- branch scope enforcement;
- device activation;
- device revocation;
- cashier credential creation;
- cashier PIN change/reset;
- credential refresh;
- duplicate request idempotency.

### 32.3 Flutter tests

Test application states and critical screens for:

- signed out;
- signed in with no merchant;
- draft/pending merchant;
- rejected merchant;
- approved merchant;
- Manager invitation;
- device setup;
- cashier login;
- forced temporary PIN change;
- expired offline credentials;
- revoked device;
- suspended cashier.

### 32.4 End-to-end acceptance scenarios

At minimum, verify:

#### Merchant onboarding

```text
Owner signs in
-> creates application
-> creates first branch draft
-> submits
-> Admin approves
-> Merchant and first Branch become active
-> Owner membership exists
```

#### POS and cashier onboarding

```text
Owner activates POS
-> Owner creates cashier
-> Cashier uses temporary PIN online
-> Cashier changes PIN
-> Device enrolls offline verifier
-> Device goes offline
-> Cashier authenticates successfully
```

#### Device revocation

```text
Device goes offline
-> Owner revokes device remotely
-> local unsynced operation remains stored
-> device reconnects
-> cloud sync is blocked
-> local data remains intact
```

#### Manager scoping

```text
Owner invites Manager to Branch A
-> Manager accepts
-> Manager can manage Branch A
-> Manager cannot manage Branch B
-> Manager cannot invite another Manager
```

#### Idempotent processing

```text
Same operation ID is submitted more than once
-> backend performs the business effect once
-> duplicate requests return the established result
```

## 33. Security Invariants

Implementation must preserve these invariants:

1. No Flutter client may grant itself a merchant role.
2. No Manager may expand their own branch scope.
3. Only the Owner may administer Manager membership.
4. Only the Owner may create or deactivate branches.
5. A POS device is never trusted merely because an Owner once signed in on it.
6. A cashier PIN is never persisted in plaintext.
7. Sensitive cashier credential documents are never directly readable by clients.
8. Offline cashier authentication is device-specific and expires after seven days without a successful trusted refresh.
9. Temporary cashier PINs require online first-use change.
10. Device revocation must be checked server-side, not only through cached token claims.
11. Unsynced local operations are preserved through authorization failures and revocation.
12. Privileged backend operations are idempotent where retries could otherwise duplicate state.
13. Audit history is immutable to normal clients.
14. Development and Production data and credentials remain separated.
15. Operational records are always attributable to concrete merchant, branch, device, and actor context.

## 34. Implementation Boundary for the Next Plan

The implementation plan following this design should cover only the identity/tenant/device/cashier milestone, including:

- Firebase DEV/PROD project integration structure;
- Flutter environment/flavor configuration;
- Firebase initialization package;
- Google Sign-In foundation;
- global user profile;
- merchant application flow;
- SariSupply Admin authorization foundation;
- merchant approval/rejection backend flow;
- merchant memberships;
- branch creation and scoping;
- Manager invitations;
- POS device activation and device identity;
- cashier creation and status;
- secure cashier PIN backend;
- first-use PIN change;
- seven-day offline credential bundle;
- local secure verifier abstraction;
- security rules;
- audit event foundation;
- emulator test harness;
- Flutter/Dart tests for this milestone.

The next plan must not expand into full POS checkout, inventory, payments, procurement, warehouse, delivery, or analytics.

## 35. Deferred Items

The following are intentionally deferred:

- full POS checkout;
- barcode scanning;
- product catalog;
- inventory ledger implementation;
- customer utang workflows;
- printer integration;
- Scan-to-Pay/payment provider implementation;
- refund/void business workflow;
- warehouse/procurement;
- driver fulfillment;
- reporting;
- BIR/formal tax compliance;
- production data migration tooling;
- third Firebase staging project.

These features depend on the security foundation defined in this specification but belong to later milestones.
