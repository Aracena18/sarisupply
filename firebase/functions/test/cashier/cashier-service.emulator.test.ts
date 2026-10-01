import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import {
  changeCashierPin, createCashier, refreshCashierCredentialBundle,
  resetCashierPin, setCashierStatus, verifyCashierPin,
} from '../../src/cashier/cashier-service';
import { createPinHasher } from '../../src/cashier/pin-kdf';

const projectId = 'demo-sarisupply-rules';
const app = initializeApp({ projectId }, 'cashier-service-tests');
const db = getFirestore(app);
const hasher = createPinHasher('test-only-server-pepper-12345678901234567890');
const owner = { auth: { uid: 'owner-1', token: {} } };
const manager = { auth: { uid: 'manager-1', token: {} } };
const device = { auth: { uid: 'device:device-1', token: {
  principalType: 'device', merchantId: 'merchant-1', deviceId: 'device-1',
} } };
const cashierInput = { merchantId: 'merchant-1', displayName: 'Ana',
  employeeCode: 'EMP-1', assignedBranchIds: ['branch-a'] };

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
  await db.doc('merchants/merchant-1/devices/device-1').set({ authUid: 'device:device-1', merchantId: 'merchant-1', branchId: 'branch-a', status: 'active' });
});
afterAll(async () => { await deleteApp(app); });

describe('cashier lifecycle', () => {
  it('limits Managers to their assigned branches', async () => {
    await expect(createCashier(db, hasher, manager, {
      ...cashierInput, assignedBranchIds: ['branch-b'],
    })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(createCashier(db, hasher, manager, {
      ...cashierInput, assignedBranchIds: ['branch-a', 'branch-b'],
    })).rejects.toMatchObject({ code: 'permission-denied' });
    await db.doc('merchants/merchant-2/branches/branch-x').set({
      merchantId: 'merchant-2', status: 'active',
    });
    await expect(createCashier(db, hasher, owner, {
      ...cashierInput, assignedBranchIds: ['branch-x'],
    })).rejects.toMatchObject({ code: 'permission-denied' });
    const created = await createCashier(db, hasher, manager, cashierInput);
    expect(created.temporaryPin).toMatch(/^\d{6}$/);
    expect((await db.doc(`merchants/merchant-1/cashierCredentials/${created.cashierId}`).get()).data())
      .not.toHaveProperty('pin');
  });

  it('requires online change of a temporary PIN and increments version', async () => {
    const { cashierId, temporaryPin } = await createCashier(db, hasher, owner, cashierInput);
    const verified = await verifyCashierPin(db, hasher, device, cashierId, temporaryPin);
    expect(verified).toMatchObject({ mustChangePin: true, credentialVersion: 1 });
    const changed = await changeCashierPin(db, hasher, device, cashierId, temporaryPin, '483920');
    expect(changed.credentialVersion).toBe(2);
    await expect(verifyCashierPin(db, hasher, device, cashierId, temporaryPin))
      .rejects.toMatchObject({ code: 'unauthenticated' });
    expect(await verifyCashierPin(db, hasher, device, cashierId, '483920'))
      .toMatchObject({ mustChangePin: false, credentialVersion: 2 });
    const bundle = await refreshCashierCredentialBundle(db, device);
    expect(bundle.cashiers[0]).toMatchObject({ cashierId, credentialVersion: 2 });
    expect(JSON.stringify(bundle)).not.toContain('483920');
    expect(bundle.cashiers[0]).not.toHaveProperty('hash');
  });

  it('reset and suspension invalidate normal sign-in', async () => {
    const { cashierId, temporaryPin } = await createCashier(db, hasher, owner, cashierInput);
    const reset = await resetCashierPin(db, hasher, manager, 'merchant-1', cashierId);
    expect(reset.credentialVersion).toBe(2);
    expect(reset.temporaryPin).not.toBe(temporaryPin);
    await setCashierStatus(db, manager, 'merchant-1', cashierId, 'suspended');
    await expect(verifyCashierPin(db, hasher, device, cashierId, reset.temporaryPin))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('locks online PIN attempts after five failures', async () => {
    const { cashierId } = await createCashier(db, hasher, owner, cashierInput);
    for (let attempt = 0; attempt < 5; attempt++) {
      await expect(verifyCashierPin(db, hasher, device, cashierId, '000000'))
        .rejects.toMatchObject({ code: 'unauthenticated' });
    }
    await expect(verifyCashierPin(db, hasher, device, cashierId, '000000'))
      .rejects.toMatchObject({ code: 'resource-exhausted' });
  });
});
