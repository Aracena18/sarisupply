import { requireCashierGrant } from '../../src/checkout/cashier-grants';
import { createHash } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeEach, afterAll, expect, it } from 'vitest';
import { createPinHasher } from '../../src/cashier/pin-kdf';
import { createCashier, changeCashierPin, verifyCashierPin } from '../../src/cashier/cashier-service';
const app = initializeApp({ projectId: 'demo-sarisupply-rules' }, 'checkout-grants');
const db = getFirestore(app);
const hasher = createPinHasher('test-only-server-pepper-12345678901234567890');
const device = { auth: { uid: 'device:d', token: { principalType: 'device', merchantId: 'm', deviceId: 'd' } } };
const owner = { auth: { uid: 'owner', token: {} } };
beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-sarisupply-rules/databases/(default)/documents`, { method: 'DELETE' });
  await db.doc('merchants/m').set({ status: 'active' });
  await db.doc('merchants/m/branches/b').set({ merchantId: 'm', status: 'active' });
  await db.doc('merchants/m/devices/d').set({ merchantId: 'm', branchId: 'b', authUid: 'device:d', status: 'active' });
  await db.doc('merchants/m/memberships/owner').set({ userId: 'owner', merchantId: 'm', role: 'owner', status: 'active', allBranches: true, branchIds: [] });
});
afterAll(() => deleteApp(app));
it('issues a hashed, seven-day grant only after permanent PIN verification', async () => {
  const c = await createCashier(db, hasher, owner, { merchantId: 'm', displayName: 'Ana', employeeCode: 'A', assignedBranchIds: ['b'] });
  const temporary = await verifyCashierPin(db, hasher, device, c.cashierId, c.temporaryPin);
  expect(temporary).not.toHaveProperty('grant');
  expect((await db.collection('merchants/m/cashierGrants').get()).size).toBe(0);
  await changeCashierPin(db, hasher, device, c.cashierId, c.temporaryPin, '483920');
  const verified = await verifyCashierPin(db, hasher, device, c.cashierId, '483920');
  const grant = (verified as any).grant;
  expect(grant).toMatchObject({ scope: { merchantId: 'm', branchId: 'b', deviceId: 'd', cashierId: c.cashierId, credentialVersion: 2 } });
  expect(Buffer.from(grant.secret, 'base64url')).toHaveLength(32);
  expect(Date.parse(grant.expiresAt) - Date.parse(grant.issuedAt)).toBe(7 * 86400000);
  const stored = (await db.doc(`merchants/m/cashierGrants/${grant.scope.grantId}`).get()).data();
  expect(stored?.secretHash).toBe(createHash('sha256').update(grant.secret).digest('hex'));
  expect(stored).not.toHaveProperty('secret');
  expect(JSON.stringify(stored)).not.toContain('483920');
  await expect(verifyCashierPin(db, hasher, device, c.cashierId, '000000')).rejects.toMatchObject({ code: 'unauthenticated' });
  expect((await db.collection('merchants/m/cashierGrants').get()).size).toBe(1);
});

it('rechecks binding, version, grant lifetime and current device before reconciliation', async () => {
  const c = await createCashier(db, hasher, owner, { merchantId: 'm', displayName: 'Ana', employeeCode: 'A', assignedBranchIds: ['b'] });
  await changeCashierPin(db, hasher, device, c.cashierId, c.temporaryPin, '483920');
  const grant = (await verifyCashierPin(db, hasher, device, c.cashierId, '483920') as any).grant;
  const check = (secret = grant.secret, scope = grant.scope, time = grant.issuedAt) =>
    db.runTransaction(tx => requireCashierGrant(db, tx, device, scope, secret, time));
  await check();
  await expect(check('BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB')).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(check(grant.secret, { ...grant.scope, cashierId: 'foreign' })).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(check(grant.secret, grant.scope, grant.expiresAt)).rejects.toMatchObject({ code: 'permission-denied' });
  await db.doc(`merchants/m/cashierCredentials/${c.cashierId}`).update({ credentialVersion: 3 });
  await expect(check()).rejects.toMatchObject({ code: 'permission-denied' });
  await db.doc(`merchants/m/cashierCredentials/${c.cashierId}`).update({ credentialVersion: 2 });
  await db.doc('merchants/m/devices/d').update({ status: 'revoked' });
  await expect(check()).rejects.toMatchObject({ code: 'permission-denied' });
});
it('cooldown cannot issue a grant', async () => {
  const c = await createCashier(db, hasher, owner, { merchantId: 'm', displayName: 'Ana', employeeCode: 'A', assignedBranchIds: ['b'] });
  await changeCashierPin(db, hasher, device, c.cashierId, c.temporaryPin, '483920');
  for (let i = 0; i < 5; i++) await expect(verifyCashierPin(db, hasher, device, c.cashierId, '000000')).rejects.toMatchObject({ code: 'unauthenticated' });
  await expect(verifyCashierPin(db, hasher, device, c.cashierId, '483920')).rejects.toMatchObject({ code: 'resource-exhausted' });
  expect((await db.collection('merchants/m/cashierGrants').get()).size).toBe(0);
});
