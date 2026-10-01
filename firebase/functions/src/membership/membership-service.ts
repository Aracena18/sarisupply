import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { writeAuditEvent } from '../common/audit';
import { requireHuman } from '../common/authz';
import type { AuthRequest } from '../common/authz';
import { runIdempotent } from '../common/idempotency';
import { requireDocumentId } from '../common/ids';

type Scope = { allBranches: boolean; branchIds: string[] };
type InviteInput = Scope & {
  merchantId: string;
  email: string;
  operationId: string;
};
type BranchInput = {
  merchantId: string;
  name: string;
  code: string;
  address: string;
  contactDetails?: Record<string, unknown>;
  operatingHours?: Record<string, unknown>;
  operationId: string;
};

const denied = () => new HttpsError('permission-denied', 'Access denied');
const invalid = (field: string) => new HttpsError('invalid-argument', `Invalid ${field}`);

function text(value: unknown, field: string, max = 300): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw invalid(field);
  return value.trim();
}

function verifiedEmail(request: AuthRequest): string {
  requireHuman(request);
  const email = request.auth?.token.email;
  if (request.auth?.token.email_verified !== true || typeof email !== 'string') {
    throw denied();
  }
  return text(email, 'verified email', 320).toLowerCase();
}

function scope(input: Scope): Scope {
  if (typeof input.allBranches !== 'boolean' || !Array.isArray(input.branchIds) ||
      !input.branchIds.every((id) => typeof id === 'string')) throw invalid('branch scope');
  const branchIds = [...new Set(input.branchIds.map((id) => requireDocumentId(id, 'branch ID')))];
  if (input.allBranches && branchIds.length) throw invalid('branch scope');
  if (!input.allBranches && !branchIds.length) throw invalid('branch scope');
  if (branchIds.length > 100) throw invalid('branch scope');
  return { allBranches: input.allBranches, branchIds };
}

async function assertOwner(
  db: Firestore, transaction: Transaction, merchantId: string, uid: string,
): Promise<void> {
  const [merchant, member] = await Promise.all([
    transaction.get(db.doc(`merchants/${merchantId}`)),
    transaction.get(db.doc(`merchants/${merchantId}/memberships/${uid}`)),
  ]);
  if (merchant.get('status') !== 'active' || member.get('userId') !== uid ||
      member.get('merchantId') !== merchantId || member.get('role') !== 'owner' ||
      member.get('status') !== 'active' || member.get('allBranches') !== true) throw denied();
}

async function assertBranches(
  db: Firestore, transaction: Transaction, merchantId: string, branchIds: string[],
): Promise<void> {
  const branches = await Promise.all(branchIds.map((branchId) =>
    transaction.get(db.doc(`merchants/${merchantId}/branches/${branchId}`))));
  if (branches.some((branch) => branch.get('merchantId') !== merchantId ||
      branch.get('status') !== 'active')) {
    throw new HttpsError('failed-precondition', 'Invitation contains an inactive branch');
  }
}

export async function createManagerInvitation(
  db: Firestore, request: AuthRequest, input: InviteInput,
): Promise<{ inviteId: string; merchantId: string }> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const email = text(input.email, 'email', 320).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw invalid('email');
  const branchScope = scope(input);
  const inviteRef = db.collection(`merchants/${merchantId}/managerInvites`).doc();
  return runIdempotent(`manager-invite:${merchantId}:${uid}:${operationId}`, async (tx) => {
    await assertOwner(db, tx, merchantId, uid);
    await assertBranches(db, tx, merchantId, branchScope.branchIds);
    tx.create(inviteRef, {
      merchantId, email, ...branchScope, status: 'active',
      expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
      createdAt: FieldValue.serverTimestamp(), createdBy: uid,
      acceptedAt: null, acceptedBy: null, revokedAt: null,
    });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'managerInvitation.created', targetType: 'managerInvite',
      targetId: inviteRef.id, operationId }, tx, db);
    return { inviteId: inviteRef.id, merchantId };
  }, db);
}

export async function listMyInvitations(db: Firestore, request: AuthRequest) {
  const email = verifiedEmail(request);
  const snapshot = await db.collectionGroup('managerInvites')
    .where('email', '==', email).where('status', '==', 'active').get();
  const now = Date.now();
  const candidates = snapshot.docs.filter((doc) => {
    const expiresAt = doc.get('expiresAt');
    return expiresAt instanceof Timestamp && expiresAt.toMillis() > now;
  });
  const merchants = await Promise.all(candidates.map((doc) =>
    db.doc(`merchants/${doc.get('merchantId')}`).get()));
  return candidates.filter((_, index) => merchants[index].get('status') === 'active')
    .map((doc) => ({
      inviteId: doc.id,
      merchantId: doc.get('merchantId') as string,
      email,
      allBranches: doc.get('allBranches') as boolean,
      branchIds: doc.get('branchIds') as string[],
      expiresAt: (doc.get('expiresAt') as Timestamp).toDate().toISOString(),
    }));
}

export async function acceptManagerInvitation(
  db: Firestore, request: AuthRequest, merchantIdInput: string, inviteIdInput: string,
): Promise<{ merchantId: string; role: 'manager'; status: 'active' }> {
  const uid = requireHuman(request);
  const email = verifiedEmail(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const inviteId = requireDocumentId(inviteIdInput, 'invitation ID');
  const inviteRef = db.doc(`merchants/${merchantId}/managerInvites/${inviteId}`);
  const membershipRef = db.doc(`merchants/${merchantId}/memberships/${uid}`);
  const projectionRef = db.doc(`users/${uid}/merchantRefs/${merchantId}`);

  return db.runTransaction(async (tx) => {
    const [merchant, invite, existing] = await Promise.all([
      tx.get(db.doc(`merchants/${merchantId}`)), tx.get(inviteRef), tx.get(membershipRef),
    ]);
    const data = invite.data();
    if (!data || data.merchantId !== merchantId || data.email !== email) throw denied();
    if (data.status === 'accepted' && data.acceptedBy === uid &&
        existing.get('status') === 'active' && existing.get('role') === 'manager') {
      return { merchantId, role: 'manager' as const, status: 'active' as const };
    }
    if (merchant.get('status') !== 'active' || data.status !== 'active' ||
        !(data.expiresAt instanceof Timestamp) || data.expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError('failed-precondition', 'Invitation is no longer valid');
    }
    if (existing.exists && (existing.get('role') !== 'manager' ||
        existing.get('status') !== 'removed')) {
      throw new HttpsError('already-exists', 'Membership already exists');
    }
    const branchScope = scope(data as Scope);
    await assertBranches(db, tx, merchantId, branchScope.branchIds);
    const now = FieldValue.serverTimestamp();
    const membership = { userId: uid, merchantId, role: 'manager', status: 'active',
      ...branchScope, createdAt: now, createdBy: data.createdBy, updatedAt: now };
    if (existing.exists) tx.set(membershipRef, membership);
    else tx.create(membershipRef, membership);
    tx.set(projectionRef, { merchantId, role: 'manager', status: 'active', updatedAt: now });
    tx.update(inviteRef, { status: 'accepted', acceptedAt: now, acceptedBy: uid });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'managerInvitation.accepted', targetType: 'membership', targetId: uid }, tx, db);
    return { merchantId, role: 'manager' as const, status: 'active' as const };
  });
}

export async function revokeManagerInvitation(
  db: Firestore, request: AuthRequest, merchantIdInput: string, inviteIdInput: string,
): Promise<void> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const inviteId = requireDocumentId(inviteIdInput, 'invitation ID');
  const ref = db.doc(`merchants/${merchantId}/managerInvites/${inviteId}`);
  await db.runTransaction(async (tx) => {
    await assertOwner(db, tx, merchantId, uid);
    const invite = await tx.get(ref);
    if (invite.get('status') !== 'active') throw new HttpsError('failed-precondition', 'Invitation is not active');
    tx.update(ref, { status: 'revoked', revokedAt: FieldValue.serverTimestamp() });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'managerInvitation.revoked', targetType: 'managerInvite', targetId: inviteId }, tx, db);
  });
}

export async function updateManagerAccess(
  db: Firestore, request: AuthRequest, merchantIdInput: string, managerUidInput: string,
  allBranches: boolean, branchIds: string[],
): Promise<void> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const managerUid = requireDocumentId(managerUidInput, 'manager UID');
  const branchScope = scope({ allBranches, branchIds });
  const ref = db.doc(`merchants/${merchantId}/memberships/${managerUid}`);
  await db.runTransaction(async (tx) => {
    await assertOwner(db, tx, merchantId, uid);
    const manager = await tx.get(ref);
    if (manager.get('role') !== 'manager' || manager.get('status') !== 'active') throw denied();
    await assertBranches(db, tx, merchantId, branchScope.branchIds);
    tx.update(ref, { ...branchScope, updatedAt: FieldValue.serverTimestamp() });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'manager.accessUpdated', targetType: 'membership', targetId: managerUid }, tx, db);
  });
}

export async function removeManager(
  db: Firestore, request: AuthRequest, merchantIdInput: string, managerUidInput: string,
): Promise<void> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const managerUid = requireDocumentId(managerUidInput, 'manager UID');
  const ref = db.doc(`merchants/${merchantId}/memberships/${managerUid}`);
  await db.runTransaction(async (tx) => {
    await assertOwner(db, tx, merchantId, uid);
    const manager = await tx.get(ref);
    if (manager.get('role') !== 'manager' || manager.get('status') !== 'active') throw denied();
    const now = FieldValue.serverTimestamp();
    tx.update(ref, { status: 'removed', updatedAt: now });
    tx.set(db.doc(`users/${managerUid}/merchantRefs/${merchantId}`),
      { merchantId, role: 'manager', status: 'removed', updatedAt: now });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'manager.removed', targetType: 'membership', targetId: managerUid }, tx, db);
  });
}

export async function createBranch(
  db: Firestore, request: AuthRequest, input: BranchInput,
): Promise<{ merchantId: string; branchId: string }> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const name = text(input.name, 'branch name');
  const code = text(input.code, 'branch code', 40);
  const address = text(input.address, 'branch address', 500);
  const contactDetails = input.contactDetails ?? {};
  const operatingHours = input.operatingHours ?? {};
  if (!contactDetails || typeof contactDetails !== 'object' || Array.isArray(contactDetails) ||
      !operatingHours || typeof operatingHours !== 'object' || Array.isArray(operatingHours)) {
    throw invalid('branch details');
  }
  const ref = db.collection(`merchants/${merchantId}/branches`).doc();
  return runIdempotent(`branch-create:${merchantId}:${uid}:${operationId}`, async (tx) => {
    await assertOwner(db, tx, merchantId, uid);
    const now = FieldValue.serverTimestamp();
    tx.create(ref, { merchantId, name, code, address, contactDetails,
      operatingHours, status: 'active', createdAt: now, createdBy: uid, updatedAt: now });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'branch.created', targetType: 'branch', targetId: ref.id,
      branchId: ref.id, operationId }, tx, db);
    return { merchantId, branchId: ref.id };
  }, db);
}

export async function deactivateBranch(
  db: Firestore, request: AuthRequest, merchantIdInput: string, branchIdInput: string,
): Promise<void> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(merchantIdInput, 'merchant ID');
  const branchId = requireDocumentId(branchIdInput, 'branch ID');
  const ref = db.doc(`merchants/${merchantId}/branches/${branchId}`);
  await db.runTransaction(async (tx) => {
    await assertOwner(db, tx, merchantId, uid);
    const branch = await tx.get(ref);
    if (branch.get('merchantId') !== merchantId || branch.get('status') !== 'active') {
      throw new HttpsError('failed-precondition', 'Branch is not active');
    }
    tx.update(ref, { status: 'inactive', updatedAt: FieldValue.serverTimestamp() });
    await writeAuditEvent({ merchantId, actorType: 'human', actorId: uid,
      action: 'branch.deactivated', targetType: 'branch', targetId: branchId,
      branchId }, tx, db);
  });
}
