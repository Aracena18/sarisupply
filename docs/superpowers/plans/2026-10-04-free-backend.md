# Phase 1: free trusted backend

Spec: `docs/superpowers/specs/2026-10-04-free-production-platform.md`.

## Global constraints

No linked Firebase billing, paid deployment, new cloud database, weakened PIN
derivation or client authority. Preserve existing workspace changes. The local
adapter is not evidence of Deno account eligibility or measured production quota.
Do not start Phase 2 until the feasibility gate passes.

### Task 1: secure HTTPS command boundary

Produce a bounded JSON POST transport, explicit environment/project configuration,
allowed web origins, Firebase ID-token and App Check validation, safe typed errors,
and a dispatcher reusing all 21 current domain commands. Use the existing Firebase
Admin services rather than duplicate business rules. Test missing/invalid tokens,
wrong environment, malformed/oversized bodies, CORS, unknown commands and safe errors
before implementation. Verify identity/PIN/retry/revocation through the transport
against the real emulators. Expected: backend build and all unit/emulator tests pass.

### Task 2: Flutter HTTPS gateway

Produce a gateway implementing the existing repository transport interface with
separate human/device Auth providers and App Check. Preserve FirebaseFunctionsException
codes used by offline/revocation handling. Endpoint configuration must be explicit,
HTTPS, and environment-scoped. No default paid callable endpoint. Test authenticated
requests, timeout/network failures, typed server denials and malformed responses
before implementation. Expected: Flutter checks and repository contracts pass.

### Task 3: runtime and capacity evidence

Produce a Deno-compatible entrypoint, fail-closed startup config, locked dependency
deployment instructions, runtime/PIN compatibility probe and explicit quota worksheet.
Separate assumptions from measured evidence; include storage indexes, retries,
other workflows and instance memory occupancy. Expected: local compatibility passes;
live account/load evidence either passes the gate or is explicitly recorded as missing.

### Task 4: verify, review and record gate

Run `bash tool/verify_harness.sh` with Node 22. Record new verification and current
state. One independent reviewer checks the entire change, then repair Important/
Critical findings with regressions. Expected: all local checks green, no blocking
review findings, and no claim of deployment/capacity proof without evidence.

## Review focus

Identity/app/environment token confusion; auth revocation and separate device
sessions; CORS versus real authorization; streamed payload limits; privileged
service behavior unchanged; network errors versus authoritative denial; service
credential/PIN leakage; absent config/quotas never silently select a paid service.
