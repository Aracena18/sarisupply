import { FieldValue } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { writeAuditEvent } from '../common/audit';
import { AuthorizationService, requireHuman } from '../common/authz';
import type { AuthRequest } from '../common/authz';
import { runIdempotent } from '../common/idempotency';
import { requireDocumentId } from '../common/ids';

export type MintDeviceToken = (
  uid: string, claims: Record<string, unknown>,
) => Promise<string>;

export interface ActivateDeviceInput {
  merchantId: string;
  branchId: string;
  displayName: string;
  platform: string;
  appVersion: string;
  operationId: string;
}

function requiredText(value: unknown, field: string, max = 100): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) {
    throw new HttpsError('invalid-argument', `Invalid ${field}`);
  }
  return value.trim();
}

function authorization(db: Firestore) {
  return new AuthorizationService(async (path) => {
    const snapshot = await db.doc(path).get();
    return snapshot.exists ? snapshot.data() ?? null : null;
  });
}

export async function activatePosDevice(
  db: Firestore, mintToken: MintDeviceToken, request: AuthRequest,
  input: ActivateDeviceInput,
): Promise<{ deviceId: string; customToken: string; merchantId: string; branchId: string }> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const branchId = requireDocumentId(input.branchId, 'branch ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const displayName = requiredText(input.displayName, 'display name');
  const platform = requiredText(input.platform, 'platform', 40);
  const appVersion = requiredText(input.appVersion, 'app version', 40);
  const ref = db.collection(`merchants/${merchantId}/devices`).doc();

  const activation = await runIdempotent(
    `device-activation:${merchantId}:${uid}:${operationId}`,
    async (tx) => {
      const authz = new AuthorizationService(async (path) => {
        const snapshot = await tx.get(db.doc(path));
        return snapshot.exists ? snapshot.data() ?? null : null;
      });
      await authz.requireBranchAccess(uid, merchantId, branchId);
      const now = FieldValue.serverTimestamp();
      tx.create(ref, {
        deviceId: ref.id, authUid: `device:${ref.id}`, merchantId, branchId,
        displayName, platform, appVersion, status: 'active',
        registeredAt: now, registeredBy: uid, lastSeenAt: null,
        lastCredentialRefreshAt: null, revokedAt: null, revokedBy: null,
      });
      await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
        action: 'posDevice.activated', targetType: 'device', targetId: ref.id,
        branchId, operationId }, tx, db);
      return { deviceId: ref.id, merchantId, branchId };
    }, db,
  );

  // A saved idempotent result must never let a former Manager mint a fresh token.
  await authorization(db).requireBranchAccess(
    uid, activation.merchantId, activation.branchId,
  );
  const current = await db.doc(
    `merchants/${activation.merchantId}/devices/${activation.deviceId}`,
  ).get();
  if (current.get('status') !== 'active' ||
      current.get('branchId') !== activation.branchId) {
    throw new HttpsError('failed-precondition', 'Device activation is no longer active');
  }
  // The merchant ID locates the authoritative device document; no role or
  // branch permission is trusted from the token.
  const customToken = await mintToken(`device:${activation.deviceId}`, {
    principalType: 'device', merchantId: activation.merchantId,
    deviceId: activation.deviceId,
  });
  return { ...activation, customToken };
}

export async function revokePosDevice(
  db: Firestore, request: AuthRequest, merchantIdInput: string,
  deviceIdInput: string,
): Promise<void> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const deviceId = requireDocumentId(deviceIdInput, 'device ID');
  const ref = db.doc(`merchants/${merchantId}/devices/${deviceId}`);
  await db.runTransaction(async (tx) => {
    const device = await tx.get(ref);
    if (device.get('merchantId') !== merchantId ||
        device.get('status') !== 'active') {
      throw new HttpsError('failed-precondition', 'Device is not active');
    }
    const branchId = requireDocumentId(device.get('branchId'), 'branch ID');
    const authz = new AuthorizationService(async (path) => {
      const snapshot = await tx.get(db.doc(path));
      return snapshot.exists ? snapshot.data() ?? null : null;
    });
    await authz.requireBranchAccess(uid, merchantId, branchId);
    tx.update(ref, { status: 'revoked', revokedAt: FieldValue.serverTimestamp(),
      revokedBy: uid });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'posDevice.revoked', targetType: 'device', targetId: deviceId,
      branchId }, tx, db);
  });
}

export async function getDeviceBootstrap(db: Firestore, request: AuthRequest) {
  const device = await authorization(db).requireActiveDevice(request);
  const [merchant, branch] = await Promise.all([
    db.doc(`merchants/${device.merchantId}`).get(),
    db.doc(`merchants/${device.merchantId}/branches/${device.branchId}`).get(),
  ]);
  return {
    merchantName: merchant.get('businessProfile.name') ?? merchant.get('displayName') ?? merchant.get('businessName') ?? device.merchantId,
    branchName: branch.get('name') ?? branch.get('displayName') ?? device.branchId,
    deviceId: requireDocumentId(request.auth?.token.deviceId, 'device ID'),
    merchantId: device.merchantId,
    branchId: device.branchId,
    displayName: device.displayName as string,
  };
}
