import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { activatePosDevice, getDeviceBootstrap, revokePosDevice } from '../../src/device/device-service';

const projectId = 'demo-sarisupply-rules';
const app = initializeApp({ projectId }, 'device-service-tests');
const db = getFirestore(app);
const owner = { auth: { uid: 'owner-1', token: {} } };
const manager = { auth: { uid: 'manager-1', token: {} } };
const mint = async (uid: string, claims: Record<string, unknown>) =>
  JSON.stringify({ uid, claims });

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run with Firestore emulator');
});
beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  await db.doc('merchants/merchant-1').set({ status: 'active' });
  await db.doc('merchants/merchant-1/branches/branch-a').set({ merchantId: 'merchant-1', status: 'active' });
  await db.doc('merchants/merchant-1/branches/branch-b').set({ merchantId: 'merchant-1', status: 'active' });
  await db.doc('merchants/merchant-1/memberships/owner-1').set({ userId: 'owner-1', merchantId: 'merchant-1', role: 'owner', status: 'active', allBranches: true, branchIds: [] });
  await db.doc('merchants/merchant-1/memberships/manager-1').set({ userId: 'manager-1', merchantId: 'merchant-1', role: 'manager', status: 'active', allBranches: false, branchIds: ['branch-a'] });
});
afterAll(async () => { await deleteApp(app); });

describe('trusted POS devices', () => {
  const input = { merchantId: 'merchant-1', branchId: 'branch-a', displayName: 'Counter tablet', platform: 'android', appVersion: '0.1.0', operationId: 'activate-1' };

  it('activates a branch-scoped device once and mints a device-only token', async () => {
    const first = await activatePosDevice(db, mint, manager, input);
    const retry = await activatePosDevice(db, mint, manager, input);
    expect(retry.deviceId).toBe(first.deviceId);
    expect((await db.collection('merchants/merchant-1/devices').get()).size).toBe(1);
    expect(JSON.parse(first.customToken)).toMatchObject({ uid: `device:${first.deviceId}`, claims: {
      principalType: 'device', merchantId: 'merchant-1', deviceId: first.deviceId,
    } });
    const principal = { auth: { uid: `device:${first.deviceId}`, token: {
      principalType: 'device', merchantId: 'merchant-1', deviceId: first.deviceId,
    } } };
    await expect(getDeviceBootstrap(db, principal)).resolves.toMatchObject({
      merchantId: 'merchant-1', branchId: 'branch-a', deviceId: first.deviceId,
    });
    await db.doc('merchants/merchant-1/memberships/manager-1').update({ status: 'removed' });
    await expect(activatePosDevice(db, mint, manager, input))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('denies out-of-scope, inactive branch, and inactive merchant activation', async () => {
    await expect(activatePosDevice(db, mint, manager, { ...input, branchId: 'branch-b' }))
      .rejects.toMatchObject({ code: 'permission-denied' });
    await db.doc('merchants/merchant-1/branches/branch-a').update({ status: 'inactive' });
    await expect(activatePosDevice(db, mint, owner, input))
      .rejects.toMatchObject({ code: 'permission-denied' });
    await db.doc('merchants/merchant-1/branches/branch-a').update({ status: 'active' });
    await db.doc('merchants/merchant-1').update({ status: 'pending_review' });
    await expect(activatePosDevice(db, mint, owner, input))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('revocation immediately blocks a stale token and a wrong tenant token', async () => {
    const activated = await activatePosDevice(db, mint, owner, input);
    const principal = { auth: { uid: `device:${activated.deviceId}`, token: {
      principalType: 'device', merchantId: 'merchant-1', deviceId: activated.deviceId,
    } } };
    const wrongTenant = { auth: { uid: principal.auth.uid, token: {
      ...principal.auth.token, merchantId: 'merchant-2',
    } } };
    await expect(getDeviceBootstrap(db, wrongTenant)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(revokePosDevice(db, manager, 'merchant-1', activated.deviceId)).resolves.toBeUndefined();
    await expect(getDeviceBootstrap(db, principal)).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(activatePosDevice(db, mint, owner, input)).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
