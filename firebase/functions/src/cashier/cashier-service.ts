import { randomInt } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { writeAuditEvent } from '../common/audit';
import { AuthorizationService, requireHuman } from '../common/authz';
import type { ActiveDevice, AuthRequest } from '../common/authz';
import { requireDocumentId } from '../common/ids';
import { createPinHasher } from './pin-kdf';
import { nextFailure, resetFailures } from './pin-rate-limit';

type PinHasher = ReturnType<typeof createPinHasher>;
type CashierStatus = 'active' | 'suspended';
type CreateCashierInput = {
  merchantId: string;
  displayName: string;
  employeeCode: string;
  assignedBranchIds: string[];
};

const denied = () => new HttpsError('permission-denied', 'Access denied');
function requiredText(value: unknown, field: string, max = 100): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) {
    throw new HttpsError('invalid-argument', `Invalid ${field}`);
  }
  return value.trim();
}
function authorization(db: Firestore, tx?: Transaction) {
  return new AuthorizationService(async (path) => {
    const snapshot = tx ? await tx.get(db.doc(path)) : await db.doc(path).get();
    return snapshot.exists ? snapshot.data() ?? null : null;
  });
}
function temporaryPin(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}
function credentialPath(merchantId: string, cashierId: string) {
  return `merchants/${merchantId}/cashierCredentials/${cashierId}`;
}
function cashierPath(merchantId: string, cashierId: string) {
  return `merchants/${merchantId}/cashiers/${cashierId}`;
}
async function authorizeHumanBranches(
  db: Firestore, tx: Transaction | undefined, uid: string, merchantId: string,
  branchIds: string[],
) {
  if (!Array.isArray(branchIds) || !branchIds.length || branchIds.length > 100 ||
      !branchIds.every((id) => typeof id === 'string')) {
    throw new HttpsError('invalid-argument', 'Invalid cashier branch assignments');
  }
  const ids = [...new Set(branchIds.map((id) => requireDocumentId(id, 'branch ID')))];
  const authz = authorization(db, tx);
  for (const branchId of ids) await authz.requireBranchAccess(uid, merchantId, branchId);
  return ids;
}
async function activeCashier(
  db: Firestore, tx: Transaction, device: ActiveDevice, cashierId: string,
) {
  const ref = db.doc(cashierPath(device.merchantId, cashierId));
  const snapshot = await tx.get(ref);
  const data = snapshot.data();
  if (data?.merchantId !== device.merchantId || data.status !== 'active' ||
      !Array.isArray(data.assignedBranchIds) ||
      !data.assignedBranchIds.includes(device.branchId)) throw denied();
  return { ref, data };
}
async function activeDeviceInTransaction(db: Firestore, tx: Transaction, request: AuthRequest) {
  return authorization(db, tx).requireActiveDevice(request);
}

export async function createCashier(
  db: Firestore, hasher: PinHasher, request: AuthRequest, input: CreateCashierInput,
): Promise<{ cashierId: string; temporaryPin: string; credentialVersion: 1 }> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const displayName = requiredText(input.displayName, 'cashier name');
  const employeeCode = requiredText(input.employeeCode, 'employee code', 40);
  const branchIds = await authorizeHumanBranches(
    db, undefined, uid, merchantId, input.assignedBranchIds,
  );
  const pin = temporaryPin();
  const verifier = await hasher.hash(pin);
  const ref = db.collection(`merchants/${merchantId}/cashiers`).doc();
  await db.runTransaction(async (tx) => {
    await authorizeHumanBranches(db, tx, uid, merchantId, branchIds);
    const now = FieldValue.serverTimestamp();
    tx.create(ref, { merchantId, displayName, employeeCode,
      assignedBranchIds: branchIds, status: 'active', mustChangePin: true,
      createdAt: now, createdBy: uid, updatedAt: now });
    tx.create(db.doc(credentialPath(merchantId, ref.id)), {
      ...verifier, credentialVersion: 1, failedAttemptCount: 0,
      lockedUntil: null, createdAt: now, updatedAt: now,
    });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'cashier.created', targetType: 'cashier', targetId: ref.id,
      details: { assignedBranchIds: branchIds } }, tx, db);
  });
  return { cashierId: ref.id, temporaryPin: pin, credentialVersion: 1 };
}

export async function setCashierStatus(
  db: Firestore, request: AuthRequest, merchantIdInput: string,
  cashierIdInput: string, status: CashierStatus,
): Promise<void> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const cashierId = requireDocumentId(cashierIdInput, 'cashier ID');
  if (status !== 'active' && status !== 'suspended') {
    throw new HttpsError('invalid-argument', 'Invalid cashier status');
  }
  const ref = db.doc(cashierPath(merchantId, cashierId));
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const data = snapshot.data();
    if (data?.merchantId !== merchantId) throw denied();
    await authorizeHumanBranches(db, tx, uid, merchantId, data.assignedBranchIds);
    tx.update(ref, { status, updatedAt: FieldValue.serverTimestamp() });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: `cashier.${status}`, targetType: 'cashier', targetId: cashierId }, tx, db);
  });
}

type OfflinePinFailure = {
  eventId: string;
  cashierId: string;
  failedAttempts: number;
  occurredAt: string;
};

export async function reportOfflinePinFailures(
  db: Firestore, request: AuthRequest, input: unknown,
): Promise<{ acceptedEventIds: string[] }> {
  if (!Array.isArray(input) || input.length === 0 || input.length > 20) {
    throw new HttpsError('invalid-argument', 'Expected 1 to 20 offline events');
  }
  const events: OfflinePinFailure[] = input.map((value) => {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new HttpsError('invalid-argument', 'Invalid offline event');
    }
    const event = value as Record<string, unknown>;
    if (typeof event.eventId !== 'string' ||
        !/^[A-Za-z0-9_-]{16,80}$/.test(event.eventId) ||
        !Number.isInteger(event.failedAttempts) ||
        (event.failedAttempts as number) < 5 ||
        (event.failedAttempts as number) > 1000 ||
        typeof event.occurredAt !== 'string' || event.occurredAt.length > 40 ||
        !Number.isFinite(Date.parse(event.occurredAt))) {
      throw new HttpsError('invalid-argument', 'Invalid offline event');
    }
    return {
      eventId: event.eventId,
      cashierId: requireDocumentId(event.cashierId, 'cashier ID'),
      failedAttempts: event.failedAttempts as number,
      occurredAt: event.occurredAt,
    };
  });
  if (new Set(events.map((event) => event.eventId)).size !== events.length) {
    throw new HttpsError('invalid-argument', 'Duplicate offline event IDs');
  }

  await db.runTransaction(async (tx) => {
    const device = await activeDeviceInTransaction(db, tx, request);
    const deviceId = requireDocumentId(request.auth?.token.deviceId, 'device ID');
    const cashierIds = [...new Set(events.map((event) => event.cashierId))];
    for (const cashierId of cashierIds) {
      const cashier = await tx.get(db.doc(cashierPath(device.merchantId, cashierId)));
      if (cashier.data()?.merchantId !== device.merchantId) throw denied();
    }

    const refs = events.map((event) => db.doc(
      `merchants/${device.merchantId}/auditEvents/offline-pin-${deviceId}-${event.eventId}`,
    ));
    const snapshots = await Promise.all(refs.map((ref) => tx.get(ref)));
    events.forEach((event, index) => {
      const existing = snapshots[index];
      if (existing.exists) {
        const details = existing.get('details') as Record<string, unknown>;
        if (existing.get('actorId') !== deviceId ||
            existing.get('action') !== 'cashier.offlinePinFailed' ||
            existing.get('targetId') !== event.cashierId ||
            details?.failedAttempts !== event.failedAttempts ||
            details?.reportedDeviceTime !== event.occurredAt) {
          throw new HttpsError(
            'already-exists', 'Offline event ID was reused with different data',
          );
        }
        return;
      }
      tx.create(refs[index], {
        merchantId: device.merchantId,
        actorType: 'device', actorId: deviceId,
        action: 'cashier.offlinePinFailed', targetType: 'cashier',
        targetId: event.cashierId, branchId: device.branchId,
        operationId: event.eventId,
        details: {
          failedAttempts: event.failedAttempts,
          reportedDeviceTime: event.occurredAt,
        },
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  });
  return { acceptedEventIds: events.map((event) => event.eventId) };
}

type PinCheck = { status: 'ok'; credentialVersion: number; mustChangePin: boolean } |
  { status: 'wrong' | 'locked' };

async function checkPin(
  db: Firestore, tx: Transaction, hasher: PinHasher, device: ActiveDevice,
  cashierId: string, pin: string,
): Promise<PinCheck> {
  const cashier = await activeCashier(db, tx, device, cashierId);
  const ref = db.doc(credentialPath(device.merchantId, cashierId));
  const credential = await tx.get(ref);
  if (!credential.exists) throw denied();
  const lockedUntil = credential.get('lockedUntil');
  if (lockedUntil instanceof Timestamp && lockedUntil.toMillis() > Date.now()) {
    return { status: 'locked' };
  }
  const valid = await hasher.verify(pin, {
    salt: credential.get('salt') as string,
    hash: credential.get('hash') as string,
  });
  if (!valid) {
    const failure = nextFailure(
      Number(credential.get('failedAttemptCount') ?? 0), Date.now(),
    );
    tx.update(ref, { failedAttemptCount: failure.failedAttemptCount,
      lockedUntil: failure.lockedUntilMs === null ? null :
        Timestamp.fromMillis(failure.lockedUntilMs) });
    return { status: 'wrong' };
  }
  tx.update(ref, { ...resetFailures(), lastVerifiedAt: FieldValue.serverTimestamp() });
  return { status: 'ok', credentialVersion: credential.get('credentialVersion') as number,
    mustChangePin: cashier.data.mustChangePin === true };
}

function requirePinSuccess(result: PinCheck): asserts result is Extract<PinCheck, { status: 'ok' }> {
  if (result.status === 'locked') {
    throw new HttpsError('resource-exhausted', 'PIN temporarily locked');
  }
  if (result.status === 'wrong') {
    throw new HttpsError('unauthenticated', 'Invalid cashier PIN');
  }
}

export async function verifyCashierPin(
  db: Firestore, hasher: PinHasher, request: AuthRequest,
  cashierIdInput: string, pin: string,
) {
  const cashierId = requireDocumentId(cashierIdInput, 'cashier ID');
  const result = await db.runTransaction(async (tx) => {
    const device = await activeDeviceInTransaction(db, tx, request);
    return checkPin(db, tx, hasher, device, cashierId, pin);
  });
  requirePinSuccess(result);
  return { cashierId, credentialVersion: result.credentialVersion,
    mustChangePin: result.mustChangePin };
}

export async function changeCashierPin(
  db: Firestore, hasher: PinHasher, request: AuthRequest,
  cashierIdInput: string, currentPin: string, newPin: string,
) {
  const cashierId = requireDocumentId(cashierIdInput, 'cashier ID');
  if (currentPin === newPin) {
    throw new HttpsError('invalid-argument', 'New PIN must be different');
  }
  await authorization(db).requireActiveDevice(request);
  const verifier = await hasher.hash(newPin);
  const result = await db.runTransaction(async (tx) => {
    const device = await activeDeviceInTransaction(db, tx, request);
    const check = await checkPin(db, tx, hasher, device, cashierId, currentPin);
    if (check.status !== 'ok') return check;
    const credentialVersion = check.credentialVersion + 1;
    tx.update(db.doc(credentialPath(device.merchantId, cashierId)), {
      ...verifier, credentialVersion, ...resetFailures(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(db.doc(cashierPath(device.merchantId, cashierId)), {
      mustChangePin: false, updatedAt: FieldValue.serverTimestamp(),
    });
    await writeAuditEvent({ merchantId: device.merchantId,
      actorType: 'cashier', actorId: cashierId, action: 'cashierPin.changed',
      targetType: 'cashier', targetId: cashierId, branchId: device.branchId }, tx, db);
    return { status: 'ok' as const, credentialVersion, mustChangePin: false };
  });
  requirePinSuccess(result);
  return { cashierId, credentialVersion: result.credentialVersion };
}

export async function resetCashierPin(
  db: Firestore, hasher: PinHasher, request: AuthRequest,
  merchantIdInput: string, cashierIdInput: string,
) {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const cashierId = requireDocumentId(cashierIdInput, 'cashier ID');
  const currentCashier = await db.doc(cashierPath(merchantId, cashierId)).get();
  if (currentCashier.get('merchantId') !== merchantId) throw denied();
  await authorizeHumanBranches(db, undefined, uid, merchantId,
    currentCashier.get('assignedBranchIds'));
  const pin = temporaryPin();
  const verifier = await hasher.hash(pin);
  const credentialVersion = await db.runTransaction(async (tx) => {
    const cashierRef = db.doc(cashierPath(merchantId, cashierId));
    const credentialRef = db.doc(credentialPath(merchantId, cashierId));
    const [cashier, credential] = await Promise.all([
      tx.get(cashierRef), tx.get(credentialRef),
    ]);
    if (cashier.get('merchantId') !== merchantId || !credential.exists) throw denied();
    await authorizeHumanBranches(
      db, tx, uid, merchantId, cashier.get('assignedBranchIds'),
    );
    const nextVersion = Number(credential.get('credentialVersion')) + 1;
    const now = FieldValue.serverTimestamp();
    tx.update(credentialRef, { ...verifier, credentialVersion: nextVersion,
      ...resetFailures(), updatedAt: now });
    tx.update(cashierRef, { mustChangePin: true, updatedAt: now });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'cashierPin.reset', targetType: 'cashier', targetId: cashierId }, tx, db);
    return nextVersion;
  });
  return { cashierId, temporaryPin: pin, credentialVersion };
}

export async function refreshCashierCredentialBundle(
  db: Firestore, request: AuthRequest,
) {
  return db.runTransaction(async (tx) => {
    const device = await activeDeviceInTransaction(db, tx, request);
    const snapshot = await tx.get(db.collection(`merchants/${device.merchantId}/cashiers`)
      .where('assignedBranchIds', 'array-contains', device.branchId)
      .where('status', '==', 'active'));
    const credentials = await Promise.all(snapshot.docs.map((cashier) =>
      tx.get(db.doc(credentialPath(device.merchantId, cashier.id)))));
    const issued = Date.now();
    return {
      merchantId: device.merchantId,
      branchId: device.branchId,
      credentialBundleIssuedAt: new Date(issued).toISOString(),
      credentialBundleExpiresAt: new Date(issued + 7 * 24 * 60 * 60 * 1000).toISOString(),
      cashiers: snapshot.docs.flatMap((cashier, index) =>
        credentials[index].exists ? [{
          cashierId: cashier.id,
          displayName: cashier.get('displayName') as string,
          employeeCode: cashier.get('employeeCode') as string,
          status: 'active' as const,
          assignedBranchIds: cashier.get('assignedBranchIds') as string[],
          mustChangePin: cashier.get('mustChangePin') as boolean,
          credentialVersion: credentials[index].get('credentialVersion') as number,
        }] : []),
    };
  });
}
