import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import {
  acceptManagerInvitation,
  createBranch,
  createManagerInvitation,
  deactivateBranch,
  listMyInvitations,
  removeManager,
  revokeManagerInvitation,
  updateManagerAccess,
} from '../../src/membership/membership-service';

const projectId = 'demo-sarisupply-rules';
const app = initializeApp({ projectId }, 'membership-service-tests');
const db = getFirestore(app);
const owner = { auth: { uid: 'owner-1', token: { email: 'owner@example.com', email_verified: true } } };
const manager = { auth: { uid: 'manager-1', token: { email: 'manager@example.com', email_verified: true } } };
const recipient = { auth: { uid: 'recipient-1', token: { email: 'recipient@example.com', email_verified: true } } };

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run with Firestore emulator');
});
beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  await db.doc('merchants/merchant-1').set({ status: 'active' });
  await db.doc('merchants/merchant-1/branches/branch-a').set({ merchantId: 'merchant-1', status: 'active' });
  await db.doc('merchants/merchant-1/branches/branch-b').set({ merchantId: 'merchant-1', status: 'inactive' });
  await db.doc('merchants/merchant-1/memberships/owner-1').set({ userId: 'owner-1', merchantId: 'merchant-1', role: 'owner', status: 'active', allBranches: true, branchIds: [] });
  await db.doc('merchants/merchant-1/memberships/manager-1').set({ userId: 'manager-1', merchantId: 'merchant-1', role: 'manager', status: 'active', allBranches: false, branchIds: ['branch-a'] });
});
afterAll(async () => { await deleteApp(app); });

describe('membership workflows', () => {
  const inviteInput = { merchantId: 'merchant-1', email: 'Recipient@Example.com', allBranches: false, branchIds: ['branch-a'], operationId: 'invite-op-1' };

  it('only lets the current Owner invite or mutate branches and managers', async () => {
    await expect(createManagerInvitation(db, manager, inviteInput)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(createBranch(db, manager, { merchantId: 'merchant-1', name: 'New', code: 'NEW', address: 'Davao', operationId: 'branch-op-1' })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(deactivateBranch(db, manager, 'merchant-1', 'branch-a')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(removeManager(db, manager, 'merchant-1', 'recipient-1')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(updateManagerAccess(db, manager, 'merchant-1', 'manager-1', true, [])).rejects.toMatchObject({ code: 'permission-denied' });
    const branch = await createBranch(db, owner, { merchantId: 'merchant-1', name: 'New', code: 'NEW', address: 'Davao', operationId: 'branch-op-1' });
    expect((await createBranch(db, owner, { merchantId: 'merchant-1', name: 'New', code: 'NEW', address: 'Davao', operationId: 'branch-op-1' })).branchId).toBe(branch.branchId);
    await deactivateBranch(db, owner, 'merchant-1', branch.branchId);
    expect((await db.doc(`merchants/merchant-1/branches/${branch.branchId}`).get()).get('status')).toBe('inactive');
  });

  it('binds invitations to verified email and accepts once', async () => {
    const { inviteId } = await createManagerInvitation(db, owner, inviteInput);
    const visible = await listMyInvitations(db, recipient);
    expect(visible.map((invite) => invite.inviteId)).toContain(inviteId);
    await expect(listMyInvitations(db, { auth: { uid: 'recipient-1', token: { email: 'recipient@example.com', email_verified: false } } })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(acceptManagerInvitation(db, manager, 'merchant-1', inviteId)).rejects.toMatchObject({ code: 'permission-denied' });
    const first = await acceptManagerInvitation(db, recipient, 'merchant-1', inviteId);
    expect(await acceptManagerInvitation(db, recipient, 'merchant-1', inviteId)).toEqual(first);
    expect((await db.doc('merchants/merchant-1/memberships/recipient-1').get()).data()).toMatchObject({ role: 'manager', email: 'recipient@example.com', branchIds: ['branch-a'], status: 'active' });
    expect((await db.doc('users/recipient-1/merchantRefs/merchant-1').get()).exists).toBe(true);
    expect((await db.collection('merchants/merchant-1/memberships').get()).size).toBe(3);
  });

  it('rejects expired, revoked, inactive branch, and duplicate memberships', async () => {
    const first = await createManagerInvitation(db, owner, inviteInput);
    await db.doc(`merchants/merchant-1/managerInvites/${first.inviteId}`).update({ expiresAt: new Date(0) });
    await expect(acceptManagerInvitation(db, recipient, 'merchant-1', first.inviteId)).rejects.toMatchObject({ code: 'failed-precondition' });
    const second = await createManagerInvitation(db, owner, { ...inviteInput, operationId: 'invite-op-2' });
    await revokeManagerInvitation(db, owner, 'merchant-1', second.inviteId);
    await expect(acceptManagerInvitation(db, recipient, 'merchant-1', second.inviteId)).rejects.toMatchObject({ code: 'failed-precondition' });
    const third = await createManagerInvitation(db, owner, { ...inviteInput, operationId: 'invite-op-3' });
    await db.doc('merchants/merchant-1/branches/branch-a').update({ status: 'inactive' });
    await expect(acceptManagerInvitation(db, recipient, 'merchant-1', third.inviteId)).rejects.toMatchObject({ code: 'failed-precondition' });
    await db.doc('merchants/merchant-1/branches/branch-a').update({ status: 'active' });
    await db.doc('merchants/merchant-1/memberships/recipient-1').set({ userId: 'recipient-1', merchantId: 'merchant-1', role: 'manager', status: 'active', allBranches: true, branchIds: [] });
    await expect(acceptManagerInvitation(db, recipient, 'merchant-1', third.inviteId)).rejects.toMatchObject({ code: 'already-exists' });
    await db.doc('merchants/merchant-1/memberships/recipient-1').update({ status: 'removed' });
    await expect(acceptManagerInvitation(db, recipient, 'merchant-1', third.inviteId))
      .resolves.toMatchObject({ status: 'active' });
  });

  it('removal revokes membership and projection', async () => {
    await updateManagerAccess(db, owner, 'merchant-1', 'manager-1', true, []);
    expect((await db.doc('merchants/merchant-1/memberships/manager-1').get()).get('allBranches')).toBe(true);
    await removeManager(db, owner, 'merchant-1', 'manager-1');
    expect((await db.doc('merchants/merchant-1/memberships/manager-1').get()).get('status')).toBe('removed');
    expect((await db.doc('users/manager-1/merchantRefs/merchant-1').get()).get('status')).toBe('removed');
    await expect(createManagerInvitation(db, manager, { ...inviteInput, operationId: 'invite-op-4' })).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
