# Security Gates

Use these gates for authentication, tenancy, branch permissions, devices, cashier credentials, privileged backend operations, payments, and sensitive operational data.

## Authorization

- Do not trust role, merchant, branch, or device authority solely from client-supplied identifiers.
- Re-check current server state for privileged operations.
- Managers cannot expand their own scope.
- Device revocation must be enforceable server-side.
- Normal clients must not write privileged authorization records directly.

## Data protection

- Never persist cashier PIN plaintext.
- Never commit service-account credentials, signing keys, peppers, provider secrets, or equivalent backend secrets.
- Use managed secret storage for backend secrets.
- Client Firebase configuration is not a substitute for authorization.

## Multi-tenant safety

Every protected business operation must be attributable to the correct merchant and applicable branch/device/actor context.

Negative tests should attempt cross-tenant and cross-branch access.

## Retry safety

Any mutation that may be retried and could duplicate a business effect must use idempotency or an equivalent deduplication mechanism.

Examples include future:

- approval;
- invitations;
- device activation;
- sales;
- refunds;
- inventory movements;
- delivery/payment confirmations.

## Offline safety

Authorization failure after reconnect must not silently delete locally durable unsynced operations.

Offline validity windows must not be extended by suspicious device-clock rollback.

## Rules and backend

Start from deny by default.

Security Rules remain defense in depth. Sensitive business authorization belongs in server-side functions/services as well.

## Review requirement

Security-sensitive changes require an independent review pass focused on:

- stale authorization;
- wrong-tenant identifiers;
- replay/duplicate requests;
- revocation;
- secret exposure;
- local credential misuse;
- unsafe failure handling.
