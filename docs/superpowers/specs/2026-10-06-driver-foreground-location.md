# Driver foreground location sharing

Approved in the implementation conversation on 2026-10-06. This is a bounded
presentation slice using the existing free Development HTTPS backend and POS
Owner Dispatch workflow. It does not establish production or pilot readiness.

## Behavior

- An assigned driver explicitly starts sharing for a dispatched/in-transit run.
  Capture and upload immediately, then every 30 seconds while Driver is open.
  Stop sharing and Update now are explicit controls.
- Request Android foreground location access; accept approximate permission and
  show reported accuracy. Denied permission, disabled GPS and timeouts have
  recovery actions. No background service or background-location permission.
- Backgrounding, Maps and screen lock pause capture; returning resumes only the
  opted-in session. Sign-out, run change and completion stop sharing. Restart
  requires starting again.
- POS Owner Dispatch opens a location card for an active route, displaying the
  latest coordinates, accuracy, capture and receipt times, sharing state and
  existing stops. Poll only the selected visible route every 30 seconds. Open in
  Maps uses an external installed maps app or an HTTPS Maps fallback.
- GPS older than 90 seconds is last known. Failed refresh never presents the
  retained snapshot as current. Authorization denial clears the owner snapshot
  and stops polling.

## Data and security

Use `manageDeliveries` actions `updateDriverLocation`, `pauseDriverLocation` and
`readDriverLocation`. Keep location gateway separate from existing delivery
contracts. Store one latest snapshot under
`merchants/{merchantId}/driverLocations/{runId}`; overwrite samples rather than
storing travel history. Include server-derived driver identity and receipt time.

Validate active merchant, warehouse, current driver assignment and run ownership
on every upload. Only the owner can read a snapshot. Client Firestore writes
remain denied. Validate finite coordinates, accuracy and fresh capture times.
Event timestamps fence delayed uploads after pause; duplicate pause is harmless.
No GPS samples enter the durable delivery outbox, and no existing business data
is deleted or migrated.

## Presentation and limits

One phone demonstrates a real GPS handoff: Driver uploads, then POS retrieves the
last position. Sharing pauses during the switch. No fake GPS, embedded map,
live ETA, optimized road route, historical trail or driver-enrollment redesign.
An existing active driver assignment and dispatched run are prerequisites.

Build matching-signature Development APKs and update the existing Development
backend. Retain the previous backend revision and privately back up phone data
before installing. Verify zero-warning static analysis, focused lifecycle and
stale-location checks, scoped backend authorization tests and actual phone GPS
capture/retrieval. Full harness remains deferred under build-focused instructions.
