import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeEach, afterAll, it, expect } from 'vitest';
import { listManagementRecords } from '../../src/management/workspace-service';
const app = initializeApp({ projectId: 'demo-sarisupply-rules' }, 'management-tests');
const db = getFirestore(app);
const owner = { auth: { uid: 'owner-workspace', token: {} } };
const manager = { auth: { uid: 'manager-workspace', token: {} } };
const root = 'merchants/workspace-merchant';
beforeEach(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Local emulator required');
  await db.recursiveDelete(db.doc(root));
  await db.doc(root).set({ status: 'active' });
  for (const [uid, role] of [['owner-workspace', 'owner'], ['manager-workspace', 'manager']]) {
    await db.doc(`${root}/memberships/${uid}`).set({ userId: uid, merchantId: 'workspace-merchant',
      role, status: 'active', allBranches: role === 'owner', branchIds: ['a'] });
  }
});
afterAll(() => deleteApp(app));
const input = { merchantId: 'workspace-merchant', kind: 'cashiers' };
it('projects safe fields without credentials or cross-branch staff', async () => {
  await db.doc(`${root}/cashiers/local`).set({ displayName: 'Ana', employeeCode: 'EMP1',
    status: 'active', assignedBranchIds: ['a'], pin: 'secret', hash: 'secret' });
  await db.doc(`${root}/cashiers/shared`).set({ displayName: 'Shared', status: 'active', assignedBranchIds: ['a', 'b'] });
  const page = await listManagementRecords(db, manager, input);
  expect(page.records).toEqual([{ id: 'local', name: 'Ana', code: 'EMP1', status: 'active', branchIds: ['a'], allBranches: false }]);
  expect(JSON.stringify(page)).not.toContain('secret');
  expect((await listManagementRecords(db, owner, input)).records).toHaveLength(2);
});
it('rejects other tenants, devices, revoked membership and owner-only lists', async () => {
  await expect(listManagementRecords(db, manager, { ...input, merchantId: 'other' })).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(listManagementRecords(db, { auth: { uid: 'device', token: { principalType: 'device' } } }, input)).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(listManagementRecords(db, manager, { ...input, kind: 'managers' })).rejects.toMatchObject({ code: 'permission-denied' });
  await db.doc(`${root}/memberships/manager-workspace`).update({ status: 'removed' });
  await expect(listManagementRecords(db, manager, input)).rejects.toMatchObject({ code: 'permission-denied' });
});
it('continues after an empty filtered page and bounds every scan', async () => {
  const batch = db.batch();
  for (let i = 0; i < 51; i++) batch.set(db.doc(`${root}/cashiers/c${String(i).padStart(3, '0')}`), {
    displayName: 'Staff', status: 'active', assignedBranchIds: [i === 50 ? 'a' : 'b'] });
  await batch.commit();
  const first = await listManagementRecords(db, manager, input);
  expect(first.records).toEqual([]); expect(first.nextCursor).toBe('c049');
  const second = await listManagementRecords(db, manager, { ...input, cursor: first.nextCursor });
  expect(second.records.map((r) => r.id)).toEqual(['c050']); expect(second.nextCursor).toBeNull();
});
it('validates collection and cursor without exposing arbitrary paths', async () => {
  await expect(listManagementRecords(db, owner, { ...input, kind: 'cashierCredentials' })).rejects.toMatchObject({ code: 'invalid-argument' });
  await expect(listManagementRecords(db, owner, { ...input, cursor: 'bad/path' })).rejects.toMatchObject({ code: 'invalid-argument' });
});
it('legacy invitation-created managers display their verified invitation email', async () => {
  await db.doc(`${root}/managerInvites/accepted`).set({ acceptedBy: 'manager-workspace',
    status: 'accepted', email: 'ana@example.test', merchantId: 'workspace-merchant' });
  const page = await listManagementRecords(db, owner, { ...input, kind: 'managers' });
  expect(page.records[0].name).toBe('ana@example.test');
});
