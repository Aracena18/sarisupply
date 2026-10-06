import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeAll, afterAll, describe, expect, it } from 'vitest';
import { grantPlatformAdmin } from '../../src/admin/admin-service';
import { createPinHasher } from '../../src/cashier/pin-kdf';
import { createCommandDispatcher } from '../../src/https/commands';
import { createHttpsHandler } from '../../src/https/handler';

const projectId = 'demo-sarisupply-rules';
const app = initializeApp({ projectId }, 'https-identity-tests');
const auth = getAuth(app);
const db = getFirestore(app);
const hasher = createPinHasher('test-only-server-pepper-12345678901234567890');
const commands = createCommandDispatcher(db, (uid, claims) => auth.createCustomToken(uid, claims), hasher);
const handler = createHttpsHandler({ environment: 'dev', projectId,
  allowedOrigins: [], allowedAppIds: ['test-app'] }, {
  ...commands,
  verifyIdToken: (token) => auth.verifyIdToken(token, true),
  // App Check has no emulator. Only this test injects attestation; hosted startup
  // always uses getAppCheck(app).verifyToken with no bypass option.
  verifyAppCheckToken: async (token) => {
    if (token !== 'test-attestation') throw new Error('Invalid test attestation');
    return { appId: 'test-app' };
  },
});
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Run with Auth and Firestore emulators');
  }
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
});
afterAll(() => deleteApp(app));

async function signIn(customToken: string): Promise<string> {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=test-key`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  });
  const result = await response.json() as { idToken: string };
  if (!result.idToken) throw new Error('Emulator sign-in failed');
  return result.idToken;
}
async function call(name: string, token: string, data: Record<string, unknown> = {}) {
  const response = await handler(new Request(`https://api.example.test/v1/commands/${name}`, {
    method: 'POST', headers: { 'content-type': 'application/json',
      authorization: `Bearer ${token}`, 'x-firebase-appcheck': 'test-attestation',
      'x-sarisupply-environment': 'dev' }, body: JSON.stringify({ data }),
  }));
  const body = await response.json() as { result: Record<string, unknown>; error?: { code: string } };
  return { status: response.status, ...body };
}

describe('HTTPS identity integration', () => {
  it('completes onboarding, PIN change, retries and current-device revocation using real ID tokens', async () => {
    const suffix = Date.now();
    const owner = `https-owner-${suffix}`;
    const admin = `https-admin-${suffix}`;
    await auth.createUser({ uid: owner, email: `${owner}@example.test`, emailVerified: true });
    await auth.createUser({ uid: admin });
    await grantPlatformAdmin(auth, db, { uid: admin });
    const ownerToken = await signIn(await auth.createCustomToken(owner));
    const adminToken = await signIn(await auth.createCustomToken(admin));
    const draft = await call('saveMerchantApplicationDraft', ownerToken, {
      businessProfile: { name: 'Sari Store' },
      firstBranchDraft: { name: 'Main', code: 'MAIN', address: 'Davao City' },
    });
    expect(draft.status).toBe(200);
    const applicationId = draft.result.applicationId;
    expect((await call('submitMerchantApplication', ownerToken, { applicationId })).status).toBe(200);
    expect((await call('reviewMerchantApplication', ownerToken, {
      applicationId, decision: 'approve', operationId: 'review-http',
    })).status).toBe(403);
    const reviewed = await call('reviewMerchantApplication', adminToken, {
      applicationId, decision: 'approve', operationId: 'review-http',
    });
    expect(reviewed.status).toBe(200);
    const { merchantId, branchId } = reviewed.result;
    const activate = { merchantId, branchId, displayName: 'Counter', platform: 'android',
      appVersion: '0.1.0', operationId: 'activate-http' };
    const activated = await call('activatePosDevice', ownerToken, activate);
    expect(activated.status).toBe(200);
    expect((await call('activatePosDevice', ownerToken, activate)).result.deviceId).toBe(activated.result.deviceId);
    const deviceToken = await signIn(activated.result.customToken as string);
    expect((await call('getDeviceBootstrap', deviceToken)).result).toMatchObject({ merchantId, branchId });
    const issued = await call('createCashier', ownerToken, { merchantId,
      displayName: 'Ana', employeeCode: 'EMP-1', assignedBranchIds: [branchId] });
    expect(issued.status).toBe(200);
    const cashierId = issued.result.cashierId;
    expect((await call('verifyCashierPin', deviceToken, { cashierId, pin: issued.result.temporaryPin })).result.mustChangePin).toBe(true);
    expect((await call('changeCashierPin', deviceToken, { cashierId,
      currentPin: issued.result.temporaryPin, newPin: '483920' })).status).toBe(200);
    expect((await call('verifyCashierPin', deviceToken, { cashierId, pin: '483920' })).result.mustChangePin).toBe(false);
    expect(JSON.stringify((await call('refreshCashierCredentialBundle', deviceToken)).result)).not.toContain('hash');
    expect((await call('revokePosDevice', ownerToken, { merchantId, deviceId: activated.result.deviceId })).status).toBe(200);
    expect(await call('getDeviceBootstrap', deviceToken)).toMatchObject({ status: 403, error: { code: 'permission-denied' } });
    expect(await call('activatePosDevice', ownerToken, activate))
      .toMatchObject({ status: 400, error: { code: 'failed-precondition' } });
  }, 20_000);
  it('rejects a disabled human with an otherwise unexpired real token', async () => {
    const uid = `https-disabled-${Date.now()}`;
    await auth.createUser({ uid });
    const token = await signIn(await auth.createCustomToken(uid));
    await auth.updateUser(uid, { disabled: true });
    expect(await call('saveMerchantApplicationDraft', token, {}))
      .toMatchObject({ status: 401, error: { code: 'unauthenticated' } });
  });
  it('preserves remaining membership, branch and cashier commands and server-derived audit context', async () => {
    const suffix = Date.now();
    const owner = `https-owner-settings-${suffix}`;
    const manager = `https-manager-${suffix}`;
    const email = `${manager}@example.test`;
    const merchantId = `https-merchant-${suffix}`;
    const branchId = 'main';
    await auth.createUser({ uid: owner });
    await auth.createUser({ uid: manager, email, emailVerified: true });
    const ownerToken = await signIn(await auth.createCustomToken(owner));
    const managerToken = await signIn(await auth.createCustomToken(manager));
    await db.doc(`merchants/${merchantId}`).set({ status: 'active' });
    await db.doc(`merchants/${merchantId}/memberships/${owner}`).set({
      userId: owner, merchantId, role: 'owner', status: 'active', allBranches: true, branchIds: [],
    });
    await db.doc(`merchants/${merchantId}/branches/${branchId}`).set({ merchantId, status: 'active' });
    const extraBranch = await call('createBranch', ownerToken, {
      merchantId, name: 'Second', code: 'SECOND', address: 'Davao', operationId: 'second-http',
    });
    expect(extraBranch.status).toBe(200);
    const invite = await call('createManagerInvitation', ownerToken, {
      merchantId, email, allBranches: false, branchIds: [branchId], operationId: 'invite-http',
    });
    const inviteId = invite.result.inviteId;
    expect((await call('listMyInvitations', managerToken)).result.invitations)
      .toMatchObject([{ inviteId, merchantId, branchIds: [branchId] }]);
    expect((await call('acceptManagerInvitation', managerToken, { merchantId, inviteId })).result.role).toBe('manager');
    const activated = await call('activatePosDevice', ownerToken, { merchantId, branchId,
      displayName: 'Counter', platform: 'android', appVersion: '0.1.0', operationId: 'settings-device' });
    const deviceToken = await signIn(activated.result.customToken as string);
    const cashier = await call('createCashier', ownerToken, { merchantId, displayName: 'Ana',
      employeeCode: 'EMP-1', assignedBranchIds: [branchId] });
    const cashierId = cashier.result.cashierId;
    expect((await call('setCashierStatus', ownerToken, { merchantId, cashierId, status: 'suspended' })).result.status).toBe('suspended');
    expect((await db.doc(`merchants/${merchantId}/cashiers/${cashierId}`).get()).get('status')).toBe('suspended');
    await call('setCashierStatus', ownerToken, { merchantId, cashierId, status: 'active' });
    const reset = await call('resetCashierPin', ownerToken, { merchantId, cashierId });
    expect(reset.status).toBe(200);
    expect((await call('verifyCashierPin', deviceToken, { cashierId, pin: reset.result.temporaryPin })).result.credentialVersion).toBe(2);
    const event = { eventId: 'http-offline-report-1234567890', cashierId, failedAttempts: 5,
      occurredAt: '2026-10-04T00:00:00.000Z' };
    for (let attempt = 0; attempt < 2; attempt++) {
      expect((await call('reportOfflinePinFailures', deviceToken, { events: [event], merchantId: 'wrong-tenant' })).result)
        .toEqual({ acceptedEventIds: [event.eventId] });
    }
    const audits = await db.collection(`merchants/${merchantId}/auditEvents`)
      .where('action', '==', 'cashier.offlinePinFailed').get();
    expect(audits.size).toBe(1);
    expect(audits.docs[0].get('branchId')).toBe(branchId);
    expect((await call('updateManagerAccess', ownerToken, {
      merchantId, managerUid: manager, allBranches: true, branchIds: [],
    })).result.status).toBe('updated');
    expect((await db.doc(`merchants/${merchantId}/memberships/${manager}`).get()).get('allBranches')).toBe(true);
    expect((await call('removeManager', ownerToken, { merchantId, managerUid: manager })).result.status).toBe('removed');
    expect((await call('createCashier', managerToken, { merchantId, displayName: 'Invalid',
      employeeCode: 'BAD', assignedBranchIds: [branchId] })).status).toBe(403);
    const secondInvite = await call('createManagerInvitation', ownerToken, {
      merchantId, email: 'unused@example.test', allBranches: true, branchIds: [], operationId: 'invite-revoke-http',
    });
    expect((await call('revokeManagerInvitation', ownerToken, { merchantId, inviteId: secondInvite.result.inviteId })).result.status).toBe('revoked');
    expect((await call('deactivateBranch', ownerToken, { merchantId, branchId: extraBranch.result.branchId })).result.status).toBe('inactive');
    expect((await db.doc(`merchants/${merchantId}/branches/${extraBranch.result.branchId}`).get()).get('status')).toBe('inactive');
  }, 20_000);
});
