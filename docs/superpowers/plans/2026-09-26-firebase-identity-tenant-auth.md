# Firebase Identity, Tenant, Device, and Cashier Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the production identity and tenancy foundation for SariSupply: two Firebase environments, Google-authenticated Owners/Managers/Admins, merchant approval, branch-scoped authorization, trusted POS devices, secure cashier PINs, and seven-day offline cashier authentication.

**Architecture:** Flutter clients depend on focused shared packages and never trust client-provided roles. Human identities use the default Firebase Auth context; each activated POS uses a separately named Firebase app/Auth context with a device custom token. Privileged mutations run through 2nd-generation TypeScript Cloud Functions, Firestore is deny-by-default, and cashier offline login uses a device-local verifier plus server-issued credential metadata.

**Tech Stack:** Flutter/Dart, Riverpod, Firebase Core/Auth/Firestore/Functions, Google Sign-In, Flutter Secure Storage, cryptography, TypeScript, Node.js 22, Cloud Functions for Firebase 2nd gen, Firebase Local Emulator Suite, Vitest, Firestore Rules Unit Testing.

**Spec:** `docs/superpowers/specs/2026-09-26-firebase-identity-tenant-auth-design.md`

## Global Constraints

- User-facing clients remain Flutter: POS Android/tablet, Driver Android, Admin Flutter Web.
- Firebase environments are exactly `dev` and `prod` for this milestone.
- Development and Production must not share Auth users, Firestore data, Functions, Storage, or credentials.
- One Google identity may belong to multiple merchants.
- Only Owners may invite/remove/change Managers.
- Only Owners may create/deactivate branches.
- Managers are branch-scoped unless `allBranches == true`.
- Cashiers are merchant-level identities with branch assignments and are not Firebase human users.
- Cashier PINs are 4–6 numeric digits; plaintext PINs are never persisted.
- Temporary PIN first use requires internet and must force a PIN change.
- Offline cashier login is allowed only on an enrolled POS device and expires seven days after the last trusted credential refresh.
- Revoked/suspended server state always wins when connectivity returns; unsynced local records are preserved.
- Sensitive mutations use Cloud Functions; clients do not directly write privileged authorization records.
- Every privileged or operational actor is attributable to merchant, branch, device, and human/cashier context as applicable.
- Firebase client configuration may be committed as non-secret application configuration; backend secrets must use Secret Manager and never enter the repository.
- Use Node.js 22 for Cloud Functions and 2nd-generation callable functions.
- Full checkout, inventory, payments, warehouse, delivery, and analytics remain out of scope.

## Review Focus

- **Stale authorization after revocation:** a revoked device or removed Manager must fail the next server-backed protected operation; add emulator tests in Tasks 6 and 7.
- **Duplicate/retried privileged requests:** merchant approval, invitation acceptance, and device activation must remain idempotent; add duplicate-request tests in Tasks 5–7.
- **Wrong-tenant identifiers from a modified client:** server must derive/verify membership, merchant, branch, and device relationships instead of trusting request IDs; add cross-tenant tests in Tasks 5–8.
- **Clock rollback during seven-day offline login:** backward/suspicious device time must force online refresh rather than extend validity; add pure-Dart tests in Task 9.
- **Credential-version drift after PIN reset/change:** a local verifier with an old server credential version must become unusable until online re-enrollment; add server and local tests in Tasks 8–9.

---

## File Structure Map

### Shared packages

Create `packages/sarisupply_auth/` for pure auth/authorization contracts and policies:

- `lib/src/auth_user.dart` — normalized authenticated human.
- `lib/src/auth_repository.dart` — human-auth interface.
- `lib/src/merchant_context.dart` — active merchant/branch context.
- `lib/src/policies/branch_access_policy.dart` — Owner/Manager branch decisions.
- `lib/src/offline/offline_credential.dart` — device-local credential metadata model.
- `lib/src/offline/offline_credential_policy.dart` — seven-day/version/clock rules.

Create `packages/sarisupply_firebase/` for Firebase adapters:

- `lib/src/bootstrap/firebase_bootstrap.dart` — default and named-device Firebase initialization.
- `lib/src/auth/firebase_google_auth_repository.dart` — Android/Web Google Sign-In.
- `lib/src/auth/firebase_device_auth_repository.dart` — secondary device Auth context.
- `lib/src/functions/*_functions.dart` — typed callable-function gateways.
- `lib/src/firestore/*_store.dart` — read-only projections where realtime reads are useful.

Extend `packages/sarisupply_models/` with explicit domain records and enums for this milestone.

### Firebase backend

Create:

- `firebase/firebase.json`
- `firebase/.firebaserc`
- `firebase/firestore.rules`
- `firebase/firestore.indexes.json`
- `firebase/storage.rules`
- `firebase/functions/package.json`
- `firebase/functions/tsconfig.json`
- `firebase/functions/src/index.ts`
- `firebase/functions/src/common/`
- `firebase/functions/src/merchant/`
- `firebase/functions/src/membership/`
- `firebase/functions/src/device/`
- `firebase/functions/src/cashier/`
- `firebase/functions/scripts/grant-admin.ts`
- `firebase/functions/test/`
- `firebase/tests/firestore.rules.test.ts`

### Flutter app features

POS:

- `apps/pos/lib/bootstrap/`
- `apps/pos/lib/features/owner_onboarding/`
- `apps/pos/lib/features/device_setup/`
- `apps/pos/lib/features/cashier_auth/`

Admin:

- `apps/admin/lib/bootstrap/`
- `apps/admin/lib/features/admin_auth/`
- `apps/admin/lib/features/merchant_review/`

Driver:

- Firebase environment bootstrap only in this milestone; no Driver business flow.

---

### Task 1: Establish Firebase environments, flavors, and package scaffolding

**Files:**
- Create: `packages/sarisupply_auth/pubspec.yaml`
- Create: `packages/sarisupply_auth/lib/sarisupply_auth.dart`
- Create: `packages/sarisupply_firebase/pubspec.yaml`
- Create: `packages/sarisupply_firebase/lib/sarisupply_firebase.dart`
- Create: `packages/sarisupply_firebase/lib/src/environment/sarisupply_environment.dart`
- Create: `packages/sarisupply_firebase/test/sarisupply_environment_test.dart`
- Create: `firebase/firebase.json`
- Create: `firebase/.firebaserc`
- Create: `firebase/firestore.rules`
- Create: `firebase/firestore.indexes.json`
- Create: `firebase/storage.rules`
- Create: `firebase/functions/package.json`
- Create: `firebase/functions/tsconfig.json`
- Modify: `.gitignore`
- Modify: `apps/pos/android/app/build.gradle.kts`
- Modify: `apps/driver/android/app/build.gradle.kts`
- Modify: `apps/pos/pubspec.yaml`
- Modify: `apps/admin/pubspec.yaml`
- Modify: `apps/driver/pubspec.yaml`
- Modify: `melos.yaml`

**Interfaces:**
- Produces: `enum SariSupplyEnvironment { dev, prod }`
- Produces: `SariSupplyEnvironment parseSariSupplyEnvironment(String value)`
- Produces: Firebase aliases `dev` and `prod`.
- Produces: Android POS IDs `com.sarisupply.sarisupply_pos.dev` and `com.sarisupply.sarisupply_pos`.
- Produces: Android Driver IDs `com.sarisupply.sarisupply_driver.dev` and `com.sarisupply.sarisupply_driver`.

- [ ] **Step 1: Write the environment parser test**

```dart
test('accepts only dev and prod', () {
  expect(parseSariSupplyEnvironment('dev'), SariSupplyEnvironment.dev);
  expect(parseSariSupplyEnvironment('prod'), SariSupplyEnvironment.prod);
  expect(() => parseSariSupplyEnvironment('staging'), throwsArgumentError);
});
```

- [ ] **Step 2: Run the test and confirm it fails because the package/parser does not exist**

Run:

```bash
cd packages/sarisupply_firebase
flutter test test/sarisupply_environment_test.dart
```

Expected: FAIL before implementation.

- [ ] **Step 3: Scaffold `sarisupply_auth` and `sarisupply_firebase`, then implement the environment parser**

Add the packages to the existing Melos glob without changing the monorepo pattern. Keep each package independently analyzable.

- [ ] **Step 4: Add Flutter dependencies using the package manager instead of hand-pinning stale versions**

Run in the relevant packages/apps:

```bash
cd packages/sarisupply_firebase
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions google_sign_in

cd ../../apps/pos
flutter pub add sarisupply_auth --path ../../packages/sarisupply_auth
flutter pub add sarisupply_firebase --path ../../packages/sarisupply_firebase
flutter pub add flutter_secure_storage cryptography uuid

cd ../admin
flutter pub add sarisupply_auth --path ../../packages/sarisupply_auth
flutter pub add sarisupply_firebase --path ../../packages/sarisupply_firebase

cd ../driver
flutter pub add sarisupply_firebase --path ../../packages/sarisupply_firebase
```

- [ ] **Step 5: Configure Android build flavors**

In POS and Driver Gradle files, create the `dev` and `prod` product flavors under one `environment` flavor dimension. Production keeps the existing application ID; development appends `.dev`. Give development apps an app-name suffix `Dev`.

- [ ] **Step 6: Create/select the two Firebase projects and register app variants**

Use Firebase CLI login under the user's Google account. Record the real project IDs only in the alias map:

```text
firebase/.firebaserc
  dev  -> actual Development project ID
  prod -> actual Production project ID
```

Register these Firebase apps in each project:

```text
POS Android prod
POS Android dev
Driver Android prod
Driver Android dev
Admin Web
```

Enable Google as an Auth provider in both projects.

- [ ] **Step 7: Generate per-app Firebase Dart configuration**

Generate committed configuration files with these exact names:

```text
apps/pos/lib/firebase_config_dev.dart
apps/pos/lib/firebase_config_prod.dart
apps/driver/lib/firebase_config_dev.dart
apps/driver/lib/firebase_config_prod.dart
apps/admin/lib/firebase_config_dev.dart
apps/admin/lib/firebase_config_prod.dart
```

Do not store backend secrets in these files. Do not commit service-account credentials.

- [ ] **Step 8: Initialize the Firebase backend workspace**

Set Functions runtime to Node.js 22 and TypeScript. Configure Firestore rules/indexes and Storage rules from the files under `firebase/`. Start with deny-all rules until Tasks 4–8 deliberately open read paths.

- [ ] **Step 9: Verify environment scaffolding**

Run:

```bash
dart run melos bootstrap
dart run melos run analyze
cd firebase/functions && npm install && npm run build
```

Expected: all commands exit 0.

- [ ] **Step 10: Commit**

```bash
git add packages/sarisupply_auth packages/sarisupply_firebase firebase apps/pos apps/admin apps/driver melos.yaml .gitignore
git commit -m "feat: scaffold Firebase environments and auth packages"
```

---

### Task 2: Add tenant/auth domain models and pure authorization policies

**Files:**
- Create: `packages/sarisupply_models/lib/src/auth/merchant_application.dart`
- Create: `packages/sarisupply_models/lib/src/auth/merchant_membership.dart`
- Create: `packages/sarisupply_models/lib/src/auth/branch.dart`
- Create: `packages/sarisupply_models/lib/src/auth/cashier.dart`
- Create: `packages/sarisupply_models/lib/src/auth/pos_device.dart`
- Create: `packages/sarisupply_models/lib/src/auth/auth_enums.dart`
- Modify: `packages/sarisupply_models/lib/sarisupply_models.dart`
- Create: `packages/sarisupply_auth/lib/src/merchant_context.dart`
- Create: `packages/sarisupply_auth/lib/src/policies/branch_access_policy.dart`
- Test: `packages/sarisupply_auth/test/branch_access_policy_test.dart`
- Test: `packages/sarisupply_models/test/auth_models_test.dart`

**Interfaces:**
- Produces: `MerchantApplicationStatus { draft, submitted, pendingReview, approved, rejected }`
- Produces: `MerchantRole { owner, manager }`
- Produces: `MembershipStatus { active, suspended, removed }`
- Produces: `CashierStatus { active, suspended }`
- Produces: `PosDeviceStatus { active, revoked }`
- Produces: `BranchAccessPolicy.canAccessBranch(MerchantMembership membership, String branchId) -> bool`
- Produces: `BranchAccessPolicy.canManageManagers(MerchantMembership membership) -> bool`
- Produces: `BranchAccessPolicy.canCreateOrDeactivateBranch(MerchantMembership membership) -> bool`

- [ ] **Step 1: Write failing policy tests**

Cover these exact cases:

```text
Owner -> every branch = allowed
Manager(allBranches=true) -> every branch = allowed
Manager(branchIds=[A]) -> A allowed, B denied
Suspended/removed membership -> every branch denied
Manager -> manage Managers denied
Owner -> manage Managers allowed
Manager -> create/deactivate branch denied
Owner -> create/deactivate branch allowed
```

- [ ] **Step 2: Run tests and confirm they fail**

Run:

```bash
cd packages/sarisupply_auth
flutter test test/branch_access_policy_test.dart
```

Expected: FAIL because models/policy are not implemented.

- [ ] **Step 3: Implement explicit immutable models and enum wire values**

Use explicit `toMap()/fromMap()` methods. Do not add code-generation dependencies in this milestone.

- [ ] **Step 4: Implement `BranchAccessPolicy`**

Policy must reject non-active memberships before checking role or branch scope.

- [ ] **Step 5: Run package tests**

```bash
cd packages/sarisupply_models && flutter test
cd ../sarisupply_auth && flutter test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/sarisupply_models packages/sarisupply_auth
git commit -m "feat: add tenant models and branch authorization policies"
```

---

### Task 3: Implement Firebase bootstrap and Google human authentication

**Files:**
- Create: `packages/sarisupply_auth/lib/src/auth_user.dart`
- Create: `packages/sarisupply_auth/lib/src/auth_repository.dart`
- Create: `packages/sarisupply_firebase/lib/src/bootstrap/firebase_bootstrap.dart`
- Create: `packages/sarisupply_firebase/lib/src/auth/firebase_google_auth_repository.dart`
- Create: `packages/sarisupply_firebase/lib/src/auth/firebase_device_auth_repository.dart`
- Create: `packages/sarisupply_firebase/lib/src/auth/google_identity_gateway.dart`
- Test: `packages/sarisupply_firebase/test/firebase_bootstrap_contract_test.dart`
- Test: `packages/sarisupply_auth/test/auth_repository_contract_test.dart`
- Create: `apps/pos/lib/bootstrap/pos_bootstrap.dart`
- Create: `apps/admin/lib/bootstrap/admin_bootstrap.dart`
- Create: `apps/driver/lib/bootstrap/driver_bootstrap.dart`
- Modify: each app's `lib/main.dart`

**Interfaces:**
- Produces: `abstract interface class AuthRepository` with `Stream<AuthUser?> authStateChanges()`, `Future<AuthUser> signInWithGoogle()`, and `Future<void> signOut()`.
- Produces: `FirebaseBootstrap.initializeHuman(FirebaseOptions options) -> Future<FirebaseApp>`.
- Produces: `FirebaseBootstrap.initializeDevice(FirebaseOptions options) -> Future<FirebaseApp>` using named app `sarisupply-device`.
- Produces: `FirebaseDeviceAuthRepository.signInWithCustomToken(String token) -> Future<String>` returning Firebase device UID.
- Consumes: `SariSupplyEnvironment` from Task 1.

- [ ] **Step 1: Write contract tests for environment-specific Firebase option selection**

Test that POS/Admin/Driver bootstraps select DEV options for `dev` and PROD options for `prod`, and reject any unsupported environment before `runApp`.

- [ ] **Step 2: Run tests and confirm they fail**

Run the package/app bootstrap tests individually.

- [ ] **Step 3: Implement default human Firebase initialization**

Initialize the default Firebase app exactly once using the selected generated `FirebaseOptions`.

- [ ] **Step 4: Implement named device Firebase initialization**

Create/reuse a named Firebase app `sarisupply-device` with the same selected environment options. Never sign the device principal into the default human Auth instance.

- [ ] **Step 5: Implement Google Sign-In**

On Android use `google_sign_in` to obtain a Google ID token, then exchange it with Firebase Auth. Initialize Google Sign-In with the environment-specific public web OAuth server client ID supplied through `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.

On Flutter Web use `FirebaseAuth.signInWithPopup(GoogleAuthProvider())`.

Normalize both into `AuthUser`.

- [ ] **Step 6: Update each app bootstrap**

Require:

```text
--dart-define=SARISUPPLY_ENV=dev|prod
```

For Android Google human auth also require the matching `GOOGLE_SERVER_CLIENT_ID` at runtime when sign-in is attempted.

- [ ] **Step 7: Verify**

Run:

```bash
dart run melos run analyze
dart run melos run test
flutter build apk --debug --flavor dev --dart-define=SARISUPPLY_ENV=dev
```

from POS and Driver as applicable, and:

```bash
flutter build web --release --dart-define=SARISUPPLY_ENV=dev
```

from Admin.

Expected: builds and tests pass without requiring a live sign-in during build.

- [ ] **Step 8: Commit**

```bash
git add packages/sarisupply_auth packages/sarisupply_firebase apps
git commit -m "feat: add Firebase bootstrap and Google authentication"
```

---

### Task 4: Build backend authorization, audit, idempotency, and SariSupply Admin bootstrap

**Files:**
- Create: `firebase/functions/src/common/authz.ts`
- Create: `firebase/functions/src/common/audit.ts`
- Create: `firebase/functions/src/common/idempotency.ts`
- Create: `firebase/functions/src/common/errors.ts`
- Create: `firebase/functions/src/common/ids.ts`
- Create: `firebase/functions/src/admin/admin-service.ts`
- Create: `firebase/functions/scripts/grant-admin.ts`
- Create: `firebase/functions/test/common/authz.test.ts`
- Create: `firebase/functions/test/common/idempotency.test.ts`
- Create: `firebase/tests/firestore.rules.test.ts`
- Modify: `firebase/firestore.rules`
- Modify: `firebase/functions/src/index.ts`

**Interfaces:**
- Produces: `requireHuman(request)`
- Produces: `requirePlatformAdmin(request)`
- Produces: `requireActiveMembership(uid, merchantId)`
- Produces: `requireOwner(uid, merchantId)`
- Produces: `requireBranchAccess(uid, merchantId, branchId)`
- Produces: `requireActiveDevice(request)`
- Produces: `writeAuditEvent(input)`
- Produces: `runIdempotent(operationKey, handler)`
- Produces admin collection: `platformAdmins/{uid}`

- [ ] **Step 1: Write failing authorization tests**

Test:

```text
no auth -> rejected
human with no membership -> rejected
active Owner -> merchant access
Manager Branch A -> Branch A allowed, Branch B rejected
removed Manager -> rejected
device principal with active device doc -> accepted
device principal with revoked device doc -> rejected
admin claim without active platformAdmins record -> rejected
active admin record + claim -> accepted
```

Include the Review Focus stale-authorization tests here.

- [ ] **Step 2: Write failing idempotency tests**

Assert that the same operation key invokes the business handler once and returns the original stored result on retry.

- [ ] **Step 3: Implement authz/audit/idempotency helpers**

Backend helpers must load current Firestore state rather than accept client role assertions.

- [ ] **Step 4: Implement trusted Admin bootstrap script**

`grant-admin.ts` accepts either `--uid <uid>` or `--email <email>`, resolves the Firebase Auth user, writes `platformAdmins/{uid}` with `status: active`, and sets custom claim `sarisupplyAdmin: true`.

Do not expose this operation as a client-callable function.

- [ ] **Step 5: Implement baseline Firestore rules**

Allow only the read paths needed for the current signed-in user and deny direct writes to:

```text
platformAdmins
merchant membership authorization
managerInvites
cashierCredentials
devices authorization fields
auditEvents
```

All privileged writes remain Admin-SDK-only.

- [ ] **Step 6: Run backend tests**

```bash
cd firebase/functions
npm test
npm run build
```

Run rules tests against the Firestore emulator.

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add firebase
git commit -m "feat: add backend authorization and audit foundation"
```

---

### Task 5: Implement merchant application and idempotent Admin approval

**Files:**
- Create: `firebase/functions/src/merchant/application-service.ts`
- Create: `firebase/functions/src/merchant/application-functions.ts`
- Test: `firebase/functions/test/merchant/application-service.test.ts`
- Create: `packages/sarisupply_auth/lib/src/merchant_application_repository.dart`
- Create: `packages/sarisupply_firebase/lib/src/functions/merchant_application_functions.dart`
- Test: `packages/sarisupply_firebase/test/merchant_application_functions_contract_test.dart`
- Modify: `firebase/functions/src/index.ts`
- Modify: `firebase/firestore.rules`

**Interfaces:**
- Produces callable `saveMerchantApplicationDraft`
- Produces callable `submitMerchantApplication`
- Produces callable `reviewMerchantApplication`
- Produces `MerchantApplicationRepository.watchMyApplications()`
- Produces `MerchantApplicationRepository.saveDraft(...)`
- Produces `MerchantApplicationRepository.submit(String applicationId)`

- [ ] **Step 1: Write failing state-transition tests**

Assert:

```text
new -> draft
draft -> submitted/pending_review
pending_review -> approved
pending_review -> rejected
rejected -> resubmitted -> pending_review
approved -> cannot be resubmitted
```

- [ ] **Step 2: Write approval idempotency and cross-tenant tests**

Assert two calls with the same review operation ID create exactly one:

```text
merchant
first active branch
Owner membership
user merchantRef
approval audit event
```

A non-admin must never approve an application, even if the request body says `role=admin`.

- [ ] **Step 3: Implement application functions**

Applicants may edit only their own draft/rejected-resubmittable application. Submission stamps server timestamps and transitions to pending review.

- [ ] **Step 4: Implement Admin review transaction**

On approve, use one trusted transaction/idempotent operation to create merchant, branch, membership, merchantRef, application result, and audit event.

On reject, preserve review notes and allow later resubmission.

- [ ] **Step 5: Implement Flutter repository/gateway**

Use callable Functions for mutations. Use Firestore only for allowed read/watch projections.

- [ ] **Step 6: Run focused tests**

Run backend merchant tests, rules tests, and Flutter package tests.

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add firebase packages/sarisupply_auth packages/sarisupply_firebase
git commit -m "feat: add merchant application and approval workflow"
```

---

### Task 6: Implement memberships, Owner-controlled branches, and Manager invitations

**Files:**
- Create: `firebase/functions/src/membership/membership-service.ts`
- Create: `firebase/functions/src/membership/invitation-functions.ts`
- Create: `firebase/functions/src/membership/branch-functions.ts`
- Test: `firebase/functions/test/membership/membership-service.test.ts`
- Create: `packages/sarisupply_auth/lib/src/membership_repository.dart`
- Create: `packages/sarisupply_firebase/lib/src/functions/membership_functions.dart`
- Modify: `firebase/functions/src/index.ts`
- Modify: `firebase/firestore.rules`

**Interfaces:**
- Produces callable `createManagerInvitation`
- Produces callable `listMyInvitations`
- Produces callable `acceptManagerInvitation`
- Produces callable `removeManager`
- Produces callable `createBranch`
- Produces callable `deactivateBranch`

- [ ] **Step 1: Write failing Owner/Manager authorization tests**

Assert:

```text
Owner can invite Manager
Manager cannot invite Manager
Owner can remove/change Manager
Manager cannot remove/change Manager
Owner can create/deactivate branch
all-branches Manager cannot create/deactivate branch
scoped Manager cannot mutate outside assigned branch
```

- [ ] **Step 2: Write invitation race/idempotency tests**

Cover:

```text
expired invitation -> reject
revoked invitation -> reject
wrong verified email -> reject
deactivated branch in invite scope -> reject
same invite accepted twice -> one membership
existing valid Manager membership -> no duplicate
```

- [ ] **Step 3: Implement Owner-only branch functions**

Branch creation/deactivation must re-check Owner membership at execution time.

- [ ] **Step 4: Implement invitation functions**

`listMyInvitations` must derive email from Firebase Auth; it must not accept arbitrary email input.

Acceptance performs validation, membership creation, invite state change, merchantRef projection, and audit write atomically/idempotently.

- [ ] **Step 5: Implement Flutter membership gateway**

Expose active memberships, branch scope, invitations, and Owner operations without exposing direct privileged Firestore writes.

- [ ] **Step 6: Run focused tests and rules tests**

Expected: PASS, including stale removed-Manager access denial.

- [ ] **Step 7: Commit**

```bash
git add firebase packages/sarisupply_auth packages/sarisupply_firebase
git commit -m "feat: add branch and manager membership workflows"
```

---

### Task 7: Implement trusted POS device activation and revocation

**Files:**
- Create: `firebase/functions/src/device/device-service.ts`
- Create: `firebase/functions/src/device/device-functions.ts`
- Test: `firebase/functions/test/device/device-service.test.ts`
- Create: `packages/sarisupply_auth/lib/src/device_repository.dart`
- Create: `packages/sarisupply_firebase/lib/src/functions/device_functions.dart`
- Modify: `packages/sarisupply_firebase/lib/src/auth/firebase_device_auth_repository.dart`
- Modify: `firebase/functions/src/index.ts`
- Modify: `firebase/firestore.rules`

**Interfaces:**
- Produces callable `activatePosDevice`
- Produces callable `revokePosDevice`
- Produces callable `getDeviceBootstrap`
- `activatePosDevice` returns `{deviceId, customToken, branchId, merchantId}`
- Device Firebase UID format: `device:{deviceId}`
- Device custom claim: `{principalType: 'device', deviceId: '<id>'}`

- [ ] **Step 1: Write failing activation tests**

Assert:

```text
Owner activates any active branch
Manager activates only assigned active branch
Manager Branch A cannot activate Branch B
pending/unapproved merchant cannot activate device
deactivated branch cannot receive a device
duplicate operation ID does not create a second device
```

- [ ] **Step 2: Write revocation tests**

Assert a device principal succeeds while active, then fails a protected backend operation immediately after its server device document is marked revoked.

- [ ] **Step 3: Implement device activation**

Generate a stable device ID server-side for a new activation request, create the device document, create a Firebase custom token, and audit activation. Do not encode merchant/branch roles into the token.

- [ ] **Step 4: Implement secondary Firebase Auth sign-in**

The POS calls `activatePosDevice` under temporary human auth, then signs the returned token into the named `sarisupply-device` Firebase Auth context. Sign the human context out after activation unless the user is actively in an Owner/Manager admin flow.

- [ ] **Step 5: Implement revocation and bootstrap**

`getDeviceBootstrap` must call `requireActiveDevice`; a stale custom token is insufficient if the device doc is revoked.

- [ ] **Step 6: Run focused tests**

Expected: PASS, including wrong-tenant and stale-revocation tests.

- [ ] **Step 7: Commit**

```bash
git add firebase packages/sarisupply_auth packages/sarisupply_firebase
git commit -m "feat: add trusted POS device identity"
```

---

### Task 8: Implement server-side cashier lifecycle and PIN credential security

**Files:**
- Create: `firebase/functions/src/cashier/pin-kdf.ts`
- Create: `firebase/functions/src/cashier/pin-rate-limit.ts`
- Create: `firebase/functions/src/cashier/cashier-service.ts`
- Create: `firebase/functions/src/cashier/cashier-functions.ts`
- Test: `firebase/functions/test/cashier/pin-kdf.test.ts`
- Test: `firebase/functions/test/cashier/cashier-service.test.ts`
- Create: `packages/sarisupply_auth/lib/src/cashier_repository.dart`
- Create: `packages/sarisupply_firebase/lib/src/functions/cashier_functions.dart`
- Modify: `firebase/functions/src/index.ts`
- Modify: `firebase/firestore.rules`

**Interfaces:**
- Produces callable `createCashier`
- Produces callable `setCashierStatus`
- Produces callable `verifyCashierPin`
- Produces callable `changeCashierPin`
- Produces callable `resetCashierPin`
- Produces callable `refreshCashierCredentialBundle`
- PIN format: `^\d{4,6}$`
- Credential doc includes `salt`, `hash`, `credentialVersion`, `failedAttemptCount`, `lockedUntil`, and timestamps.
- Server KDF: Node `crypto.scrypt`, 16-byte random salt, 32-byte output, `N=16384, r=8, p=1`, with Secret Manager pepper `CASHIER_PIN_PEPPER`.

- [ ] **Step 1: Write failing PIN KDF tests**

Assert:

```text
valid PIN verifies
wrong PIN fails
same PIN with different salt yields different stored hash
stored representation never contains plaintext PIN
missing pepper causes service initialization failure
```

- [ ] **Step 2: Write failing cashier authorization tests**

Assert:

```text
Owner creates cashier
Manager creates cashier only within assigned branch scope
cross-merchant branch ID rejected
suspended cashier cannot authenticate
temporary PIN authentication returns mustChangePin=true
reset increments credentialVersion
change increments credentialVersion
```

- [ ] **Step 3: Write rate-limit tests**

Use this concrete policy:

```text
failures 1–4: no enforced cooldown
failure 5: 30 seconds
failure 6: 60 seconds
failure 7: 120 seconds
subsequent failures: exponential backoff capped at 15 minutes
successful verification: reset failure counter and lock
```

- [ ] **Step 4: Implement server credential service**

Never return server hash, salt, or pepper-derived material to Flutter clients.

- [ ] **Step 5: Implement temporary PIN/change/reset behavior**

First successful temporary-PIN verification may establish a protected change session but must not make that temporary PIN offline-capable. Permanent PIN change creates a new credential version.

- [ ] **Step 6: Implement credential refresh projection**

For the device's branch return only cashier operational projection and:

```text
cashierId
status
branch authorization
credentialVersion
credentialBundleIssuedAt
credentialBundleExpiresAt = server time + 7 days
```

Do not return the server verifier.

- [ ] **Step 7: Store the real pepper in Secret Manager for DEV before live function testing**

Never place the pepper in `.env`, Dart, Firestore, or git.

- [ ] **Step 8: Run backend and rules tests**

Expected: PASS, including old credential-version rejection after change/reset.

- [ ] **Step 9: Commit**

```bash
git add firebase packages/sarisupply_auth packages/sarisupply_firebase
git commit -m "feat: add secure cashier credential backend"
```

---

### Task 9: Implement device-local offline cashier verifier and seven-day policy

**Files:**
- Create: `packages/sarisupply_auth/lib/src/offline/offline_credential.dart`
- Create: `packages/sarisupply_auth/lib/src/offline/offline_credential_policy.dart`
- Test: `packages/sarisupply_auth/test/offline_credential_policy_test.dart`
- Create: `apps/pos/lib/features/cashier_auth/data/local_pin_verifier.dart`
- Create: `apps/pos/lib/features/cashier_auth/data/secure_offline_credential_store.dart`
- Create: `apps/pos/lib/features/cashier_auth/domain/cashier_login_service.dart`
- Test: `apps/pos/test/features/cashier_auth/local_pin_verifier_test.dart`
- Test: `apps/pos/test/features/cashier_auth/cashier_login_service_test.dart`

**Interfaces:**
- Produces: `OfflineCredentialPolicy.evaluate(OfflineCredential credential, DateTime now, DateTime lastObservedWallClock, int serverCredentialVersion) -> OfflineCredentialDecision`
- Decisions: `allowed`, `requiresOnlineRefresh`, `requiresOnlineReenrollment`.
- Produces: `LocalPinVerifier.derive(pin, salt) -> Future<List<int>>`.
- Local KDF: PBKDF2-HMAC-SHA256, 210,000 iterations, 32-byte output, random 16-byte salt.
- Produces: `SecureOfflineCredentialStore` backed by `flutter_secure_storage`.

- [ ] **Step 1: Write failing seven-day policy tests**

Assert:

```text
bundle age < 7 days + matching credentialVersion -> allowed
bundle expired -> requiresOnlineRefresh
server credentialVersion newer than local -> requiresOnlineReenrollment
cashier suspended in refreshed projection -> no local login
```

- [ ] **Step 2: Add the Review Focus clock rollback test**

If `now` is more than five minutes earlier than `lastObservedWallClock`, return `requiresOnlineRefresh`; never extend expiry from the rolled-back clock.

- [ ] **Step 3: Write failing local verifier tests**

Assert correct PIN matches, wrong PIN fails, plaintext PIN is not stored, and two salts produce different verifier bytes.

- [ ] **Step 4: Implement secure local credential storage**

Store only:

```text
cashierId
deviceId
credentialVersion
salt
derivedVerifier
bundleIssuedAt
bundleExpiresAt
lastObservedWallClock
failedAttempts/cooldown state
```

- [ ] **Step 5: Implement offline login service**

Behavior:

```text
online + valid server PIN:
  validate server
  if permanent credential -> derive/update local verifier
  save server bundle metadata
  open cashier session

offline:
  evaluate bundle/version/time
  apply local retry cooldown
  verify local derived verifier
  open session only if allowed
```

- [ ] **Step 6: Implement offline retry controls**

Mirror the server cooldown shape locally but keep local lockout temporary. Queue a security event for later sync after repeated failures.

- [ ] **Step 7: Run tests**

```bash
cd packages/sarisupply_auth && flutter test
cd ../../apps/pos && flutter test test/features/cashier_auth
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add packages/sarisupply_auth apps/pos
git commit -m "feat: add seven-day offline cashier authentication"
```

---

### Task 10: Build Owner onboarding, POS activation, cashier login, and Admin review UI states

**Files:**
- Create: `apps/pos/lib/features/owner_onboarding/presentation/owner_onboarding_gate.dart`
- Create: `apps/pos/lib/features/owner_onboarding/presentation/merchant_application_screen.dart`
- Create: `apps/pos/lib/features/device_setup/presentation/device_setup_screen.dart`
- Create: `apps/pos/lib/features/cashier_auth/presentation/cashier_login_screen.dart`
- Create: `apps/pos/lib/features/cashier_auth/presentation/change_temporary_pin_screen.dart`
- Create: `apps/pos/lib/features/cashier_auth/presentation/offline_auth_blocked_screen.dart`
- Create: `apps/pos/lib/app/pos_app_gate.dart`
- Modify: `apps/pos/lib/main.dart`
- Create: `apps/admin/lib/features/admin_auth/presentation/admin_auth_gate.dart`
- Create: `apps/admin/lib/features/merchant_review/presentation/merchant_review_list_screen.dart`
- Create: `apps/admin/lib/features/merchant_review/presentation/merchant_review_detail_screen.dart`
- Create: `apps/admin/lib/app/admin_app_gate.dart`
- Modify: `apps/admin/lib/main.dart`
- Test: corresponding widget tests under `apps/pos/test/features/` and `apps/admin/test/features/`

**Interfaces:**
- Consumes repositories/functions from Tasks 3–9.
- Produces POS gate states: `signedOut`, `noMerchant`, `pendingMerchant`, `approvedNeedsDeviceActivation`, `deviceReadyCashierLocked`, `cashierActive`, `deviceRevoked`, `offlineCredentialsExpired`.
- Produces Admin gate states: `signedOut`, `signedInNotAdmin`, `adminReady`.

- [ ] **Step 1: Write POS gate widget tests**

Use fake repositories to assert exact screens for:

```text
signed out
no merchant -> onboarding
pending merchant -> status/setup
approved merchant without trusted device -> activation
trusted device -> cashier login
revoked device -> blocked/recovery message
expired offline bundle -> reconnect-required message
```

- [ ] **Step 2: Run tests and confirm they fail**

Run the new POS widget tests only.

- [ ] **Step 3: Implement Owner onboarding UI**

Keep the first milestone UI functional and simple. Applicant can edit business profile and first branch draft, submit, and see pending/rejected/approved state.

Do not expose sales/inventory screens yet.

- [ ] **Step 4: Implement POS activation UI**

Owner/Manager Google sign-in is temporary. Merchant and branch choices come only from active authorized memberships. On success, establish the device Firebase context and return to cashier login.

- [ ] **Step 5: Implement cashier login and forced PIN-change UI**

Temporary PIN must route to online PIN change before POS unlock. Offline-expired credentials show reconnect instructions rather than a raw exception.

- [ ] **Step 6: Write Admin widget tests**

Assert:

```text
non-admin Google user -> access denied
active admin -> review list
approve action -> calls review repository exactly once
reject requires review note input
```

- [ ] **Step 7: Implement Admin auth and merchant-review screens**

Admin list/read state may use Firestore projections; approve/reject mutations use callable Functions.

- [ ] **Step 8: Keep Driver app bootstrapped only**

Verify the Driver app initializes the selected Firebase environment but do not add merchant/cashier screens.

- [ ] **Step 9: Run all Flutter tests and builds**

```bash
dart run melos run verify

cd apps/admin
flutter build web --release --dart-define=SARISUPPLY_ENV=dev

cd ../pos
flutter build apk --debug --flavor dev --dart-define=SARISUPPLY_ENV=dev

cd ../driver
flutter build apk --debug --flavor dev --dart-define=SARISUPPLY_ENV=dev
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add apps
git commit -m "feat: add merchant approval and POS authentication flows"
```

---

### Task 11: Add emulator acceptance coverage and repository verification commands

**Files:**
- Create: `firebase/tests/identity-tenant.acceptance.test.ts`
- Create: `tool/verify_firebase.sh`
- Modify: `tool/verify_local.sh`
- Modify: `README.md`
- Modify: `docs/architecture/SARI_SUPPLY_PRODUCTION_PLAN.md`

**Interfaces:**
- Produces: `bash tool/verify_firebase.sh`
- Extends: `bash tool/verify_local.sh` so Flutter verification remains available even when live Firebase credentials are absent.

- [ ] **Step 1: Write the end-to-end emulator acceptance test**

Cover the approved happy path:

```text
Owner auth
-> save/submit merchant application
-> Admin approval
-> merchant + first branch + Owner membership
-> Owner activates POS
-> Owner creates cashier
-> cashier verifies temporary PIN online
-> cashier changes permanent PIN
-> credential bundle issued
-> offline verifier can be enrolled
```

- [ ] **Step 2: Add the three critical negative acceptance scenarios**

Scenario A:

```text
Manager Branch A
-> Branch A operation succeeds
-> Branch B operation denied
-> Manager invitation creation denied
```

Scenario B:

```text
Device active
-> protected device call succeeds
-> Owner revokes device
-> same Firebase device session calls again
-> server denies because device doc is revoked
```

Scenario C:

```text
same idempotency key sent twice for approval/invite/device activation
-> one business effect
-> stable returned result
```

- [ ] **Step 3: Create `tool/verify_firebase.sh`**

The script must:

1. install Functions/test dependencies when missing;
2. build TypeScript;
3. run pure Functions tests;
4. start Auth + Firestore + Functions emulators with a demo project;
5. run rules and acceptance tests;
6. exit non-zero on any failure.

It must never point emulator tests at the Production project.

- [ ] **Step 4: Update local verification**

Keep existing Flutter format/analyze/test/build checks. Add a clear optional Firebase verification phase when Node/npm/Firebase CLI are installed; do not silently skip a requested Firebase verification.

- [ ] **Step 5: Run fresh full verification**

Run:

```bash
bash tool/verify_firebase.sh
bash tool/verify_local.sh
git status --short
```

Expected:

```text
Functions build: PASS
Functions unit tests: PASS
Firestore rules tests: PASS
Firebase emulator acceptance tests: PASS
Flutter format: PASS
Flutter analyze: PASS
Flutter tests: PASS
Admin DEV web build: PASS
POS DEV APK build: PASS
Driver DEV APK build: PASS
```

- [ ] **Step 6: Perform manual DEV smoke test**

With the real Development Firebase project only:

1. sign in as applicant;
2. submit a merchant application;
3. grant one known test user SariSupply Admin via the trusted script;
4. approve the application in Admin Web;
5. activate one POS DEV installation;
6. create one test cashier;
7. complete temporary-PIN change;
8. disable network;
9. confirm offline login;
10. reconnect and confirm credential refresh.

Do not use Production for this smoke test.

- [ ] **Step 7: Commit**

```bash
git add firebase tool README.md docs
git commit -m "test: add Firebase identity milestone acceptance coverage"
```

---

## Plan Self-Review

### Spec coverage

- DEV/PROD separation: Task 1.
- Google human identity and multi-merchant-compatible contracts: Tasks 2–3.
- SariSupply Admin pre-authorization: Task 4.
- Self-registration, pending setup, approval/rejection/resubmission: Task 5 and Task 10.
- Owner-only Manager administration and branch administration: Task 6.
- Branch-scoped Manager access: Tasks 2, 4, 6.
- Trusted POS device identity and revocation: Task 7.
- Merchant-level cashier identities and secure server credentials: Task 8.
- Temporary PIN forced change and reset/versioning: Task 8 and Task 10.
- Seven-day device-specific offline login: Task 9.
- Audit/idempotency/deny-by-default rules: Tasks 4–8.
- Emulator and end-to-end validation: Task 11.
- Sales/inventory/payment scope exclusion: maintained across all tasks.

### Type consistency

- Human auth uses `AuthUser`/`AuthRepository`.
- Merchant permissions use `MerchantMembership` and `BranchAccessPolicy`.
- Device Auth always uses named Firebase app `sarisupply-device`.
- Device backend UID is always `device:{deviceId}`.
- Server cashier credential version and local offline credential version use the same integer version semantic.
- Callable function names are fixed in the tasks that define them and reused by later gateways/UI.

### Review Focus coverage

All five Review Focus items have explicit tests:
- stale authorization: Tasks 4, 6, 7;
- duplicate/retry idempotency: Tasks 5–7 and 11;
- wrong tenant IDs: Tasks 5–8;
- clock rollback: Task 9;
- credential version drift: Tasks 8–9.

### Scope

This plan deliberately stops after authentication, tenancy, approval, trusted devices, cashier credentials, offline login, and acceptance coverage. It does not begin checkout, inventory, restocking, payments, warehouse, delivery, or analytics.
