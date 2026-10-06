# Identity Workspace Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans task by task.

**Goal:** Make existing enrollment, staff/device management and recovery usable.
**Architecture:** Reuse identity services; add one projected, paginated HTTPS read
and a pure Dart management repository. Flutter screens use current mutation
repositories and one shared responsive page component.
**Tech Stack:** Existing Flutter Material 3, Firebase Admin/Firestore, HTTPS.
**Spec:** `docs/superpowers/specs/2026-10-04-identity-workspace.md`.

## Global constraints

Firebase Spark/no paid services. No broader backend-feasibility claim. Preserve
tenant/device/PIN/offline invariants. No new product dependencies. Retain Phase 1
and preexisting working-tree changes; native execution with one final reviewer.

## Review focus

Filtered empty pages must retain pagination; scoped managers must not see or
modify cross-branch staff; temporary PINs never persist; uncertain creation must
not duplicate records; device management must not sign out an activated device.

### Task 1: safe management projection and creation retries

Files: `firebase/functions/src/management/workspace-service.ts`, HTTPS registry,
cashier service; management emulator tests and cashier regression tests.
Produces: `listManagementRecords(db, request, {merchantId, kind, cursor?})`
returning `{records, nextCursor}`. Allowed kinds: branches/cashiers/devices/
managers/invitations. Records are explicit safe fields only.

- [x] Add negative, pagination, secret exclusion and creation-replay tests; observe RED.
- [x] Implement current membership/branch enforcement and bounded projection.
- [x] Supply optional `operationId` to cashier creation; preserve legacy callers.
- [x] Run backend build and Firebase emulator checks; expect GREEN.

### Task 2: Flutter management workspace

Files: auth management repository, Firebase management adapter, shared page/error
helpers, POS management screen/form dialogs and gate/workflow integration.
Consumes Task 1; existing membership/device/cashier repositories mutate records.

- [x] Add repository contract and widget tests for validation, pagination,
  role controls, confirmation and PIN disclosure; observe RED.
- [x] Implement management lists and typed action forms, stable retry IDs,
  temporary PIN dialog and separate human-session cleanup.
- [x] Add named cashier selection with ID fallback; test safe offline behavior.
- [x] Run Flutter formatting, analysis and focused tests; expect GREEN.

### Task 3: practical enrollment/review/recovery

Files: existing POS onboarding/activation/PIN/gate and Admin auth/review screens.

- [x] Add regressions for retry IDs, saved draft resubmission, safe errors,
  search and phone/tablet layouts; observe RED.
- [x] Implement safe copy, busy guards, concise labels and recovery actions.
- [x] Run fast harness, then full harness with Node 22; expect PASS.
- [x] One fresh review, fix important findings with RED/GREEN, final verification.
- [x] Update current state and record unresolved hosted/hardware acceptance.
