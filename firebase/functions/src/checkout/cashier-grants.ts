import { createHash, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { ActiveDevice, AuthRequest, AuthorizationService } from '../common/authz';
import { requireDocumentId } from '../common/ids';
export const grantLifetimeMs = 7 * 86400000;
export type GrantScope = { merchantId: string; branchId: string; deviceId: string; cashierId: string; grantId: string; credentialVersion: number };
export function newGrantCredential() { return { grantId: randomUUID(), secret: randomBytes(32).toString('base64url') }; }
export const hashGrantSecret = (secret: string) => createHash('sha256').update(secret).digest('hex');
export function issueCashierGrant(db: Firestore, tx: Transaction, device: ActiveDevice,
  request: AuthRequest, cashierId: string, credentialVersion: number,
  credential: ReturnType<typeof newGrantCredential>, now = Date.now()) {
  const scope: GrantScope = { merchantId: device.merchantId, branchId: device.branchId,
    deviceId: requireDocumentId(request.auth?.token.deviceId, 'device ID'), cashierId, credentialVersion, grantId: credential.grantId };
  const issuedAt = new Date(now).toISOString(), expiresAt = new Date(now + grantLifetimeMs).toISOString();
  tx.create(db.doc(`merchants/${scope.merchantId}/cashierGrants/${scope.grantId}`), {
    scope, issuedAt, expiresAt, secretHash: hashGrantSecret(credential.secret),
  });
  return { scope, secret: credential.secret, issuedAt, expiresAt };
}
/// Original device time is bounded evidence, not independent proof of offline time.
export async function requireCashierGrant(db: Firestore, tx: Transaction,
  request: AuthRequest, scope: GrantScope, secret: unknown, occurredAt: string) {
  const denied = () => new HttpsError('permission-denied', 'Checkout access expired; reconnect and sign in');
  for (const id of [scope.merchantId, scope.branchId, scope.deviceId, scope.cashierId, scope.grantId]) requireDocumentId(id, 'checkout scope');
  const authz = new AuthorizationService(async path => {
    const snap = await tx.get(db.doc(path)); return snap.exists ? snap.data() ?? null : null;
  });
  const device = await authz.requireActiveDevice(request);
  if (device.merchantId !== scope.merchantId || device.branchId !== scope.branchId ||
      request.auth?.token.deviceId !== scope.deviceId || !Number.isSafeInteger(scope.credentialVersion)) throw denied();
  const base = `merchants/${scope.merchantId}`;
  const [cashier, credential, grant] = await Promise.all([
    tx.get(db.doc(`${base}/cashiers/${scope.cashierId}`)), tx.get(db.doc(`${base}/cashierCredentials/${scope.cashierId}`)),
    tx.get(db.doc(`${base}/cashierGrants/${scope.grantId}`)),
  ]);
  if (cashier.get('merchantId') !== scope.merchantId || cashier.get('status') !== 'active' ||
      cashier.get('mustChangePin') !== false || !cashier.get('assignedBranchIds')?.includes(scope.branchId) ||
      credential.get('credentialVersion') !== scope.credentialVersion || !grant.exists) throw denied();
  const bound = grant.get('scope') as GrantScope;
  if (!bound || Object.keys(scope).some(key => scope[key as keyof GrantScope] !== bound[key as keyof GrantScope])) throw denied();
  if (typeof secret !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(secret)) throw denied();
  const storedHash = grant.get('secretHash'), actual = hashGrantSecret(secret);
  if (typeof storedHash !== 'string' || !/^[a-f0-9]{64}$/.test(storedHash) ||
      !timingSafeEqual(Buffer.from(storedHash), Buffer.from(actual))) throw denied();
  const start = Date.parse(grant.get('issuedAt')), end = Date.parse(grant.get('expiresAt')), time = Date.parse(occurredAt);
  if (![start, end, time].every(Number.isFinite) || end <= start || end - start > grantLifetimeMs ||
      time < start || time >= end || time > Date.now() + 5 * 60000) throw denied();
}
