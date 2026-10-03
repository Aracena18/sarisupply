import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { grantPlatformAdmin } from '../src/admin/admin-service';
import {
  changeCashierPin, createCashier, refreshCashierCredentialBundle,
  reportOfflinePinFailures, verifyCashierPin,
} from '../src/cashier/cashier-service';
import { createPinHasher } from '../src/cashier/pin-kdf';
import { activatePosDevice, getDeviceBootstrap, revokePosDevice } from '../src/device/device-service';
import {
  createManagerInvitation, acceptManagerInvitation, createBranch,
} from '../src/membership/membership-service';
import {
  reviewMerchantApplication, saveMerchantApplicationDraft,
  submitMerchantApplication,
} from '../src/merchant/application-service';

const projectId = 'demo-sarisupply-rules';
const app = initializeApp({ projectId }, 'identity-acceptance-tests');
const db = getFirestore(app);
const auth = getAuth(app);
const hasher = createPinHasher('test-only-server-pepper-12345678901234567890');
const mint = async (uid: string, claims: Record<string, unknown>) =>
  JSON.stringify({ uid, claims });
let sequence = 0;

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Run acceptance tests with Auth and Firestore emulators');
  }
});
beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  sequence++;
});
afterAll(async () => { await deleteApp(app); });

async function identity(role: string) {
  const uid = `${role}-${Date.now()}-${sequence}`;
  const email = `${uid}@example.test`;
  await auth.createUser({ uid, email, emailVerified: true });
  return { uid, email, request: { auth: { uid, token: { email, email_verified: true } } } };
}

async function approvedMerchant() {
  const owner = await identity('owner');
  const admin = await identity('admin');
  await grantPlatformAdmin(auth, db, { uid: admin.uid });
  expect((await auth.getUser(admin.uid)).customClaims?.sarisupplyAdmin).toBe(true);
  const draft = await saveMerchantApplicationDraft(db, owner.uid, {
    businessProfile: { name: 'Sari Store' },
    firstBranchDraft: { name: 'Main', code: 'MAIN', address: 'Davao City' },
  });
  await submitMerchantApplication(db, owner.uid, draft.applicationId);
  const review = await reviewMerchantApplication(db, {
    auth: { uid: admin.uid, token: { sarisupplyAdmin: true } },
  }, { applicationId: draft.applicationId, decision: 'approve', operationId: 'review-1' });
  return { owner, admin, applicationId: draft.applicationId,
    merchantId: review.merchantId!, branchId: review.branchId! };
}

describe('identity and tenant acceptance', () => {
  it('takes an Owner from application through POS and permanent cashier PIN', async () => {
    const { owner, merchantId, branchId } = await approvedMerchant();
    expect((await db.doc(`merchants/${merchantId}/memberships/${owner.uid}`).get()).get('role'))
      .toBe('owner');
    const activated = await activatePosDevice(db, mint, owner.request, {
      merchantId, branchId, displayName: 'Counter tablet', platform: 'android',
      appVersion: '0.1.0', operationId: 'activate-1',
    });
    const device = { auth: { uid: `device:${activated.deviceId}`, token: {
      principalType: 'device', merchantId, deviceId: activated.deviceId,
    } } };
    const issued = await createCashier(db, hasher, owner.request, {
      merchantId, displayName: 'Ana', employeeCode: 'EMP-1',
      assignedBranchIds: [branchId],
    });
    expect(await verifyCashierPin(db, hasher, device, issued.cashierId, issued.temporaryPin))
      .toMatchObject({ mustChangePin: true, credentialVersion: 1 });
    await changeCashierPin(db, hasher, device, issued.cashierId,
      issued.temporaryPin, '483920');
    expect(await verifyCashierPin(db, hasher, device, issued.cashierId, '483920'))
      .toMatchObject({ mustChangePin: false, credentialVersion: 2 });
    const bundle = await refreshCashierCredentialBundle(db, device);
    expect(bundle.cashiers).toMatchObject([{
      cashierId: issued.cashierId, credentialVersion: 2, mustChangePin: false,
    }]);
    expect(JSON.stringify(bundle)).not.toContain('hash');
    expect(JSON.stringify(bundle)).not.toContain('salt');
  });

  it('keeps a Manager scoped to Branch A and forbids Manager invitations', async () => {
    const { owner, merchantId, branchId } = await approvedMerchant();
    const otherBranch = await createBranch(db, owner.request, {
      merchantId, name: 'Other', code: 'OTHER', address: 'Davao',
      operationId: 'branch-2',
    });
    const manager = await identity('manager');
    const invite = await createManagerInvitation(db, owner.request, {
      merchantId, email: manager.email, allBranches: false,
      branchIds: [branchId], operationId: 'invite-1',
    });
    await acceptManagerInvitation(db, manager.request, merchantId, invite.inviteId);
    await expect(activatePosDevice(db, mint, manager.request, {
      merchantId, branchId, displayName: 'Branch A tablet', platform: 'android',
      appVersion: '0.1.0', operationId: 'manager-activate-a',
    })).resolves.toMatchObject({ branchId });
    await expect(activatePosDevice(db, mint, manager.request, {
      merchantId, branchId: otherBranch.branchId, displayName: 'Wrong tablet',
      platform: 'android', appVersion: '0.1.0', operationId: 'manager-activate-b',
    })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(createManagerInvitation(db, manager.request, {
      merchantId, email: 'another@example.test', allBranches: true,
      branchIds: [], operationId: 'manager-invite',
    })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects the same device token immediately after revocation', async () => {
    const { owner, merchantId, branchId } = await approvedMerchant();
    const activated = await activatePosDevice(db, mint, owner.request, {
      merchantId, branchId, displayName: 'Counter tablet', platform: 'android',
      appVersion: '0.1.0', operationId: 'activate-1',
    });
    const device = { auth: { uid: `device:${activated.deviceId}`, token: {
      principalType: 'device', merchantId, deviceId: activated.deviceId,
    } } };
    await expect(getDeviceBootstrap(db, device)).resolves.toMatchObject({ branchId });
    await revokePosDevice(db, owner.request, merchantId, activated.deviceId);
    await expect(getDeviceBootstrap(db, device))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('accepts offline PIN failure reports once and rejects a revoked device', async () => {
    const { owner, merchantId, branchId } = await approvedMerchant();
    const activated = await activatePosDevice(db, mint, owner.request, {
      merchantId, branchId, displayName: 'Counter tablet', platform: 'android',
      appVersion: '0.1.0', operationId: 'activate-1',
    });
    const device = { auth: { uid: `device:${activated.deviceId}`, token: {
      principalType: 'device', merchantId, deviceId: activated.deviceId,
    } } };
    const cashier = await createCashier(db, hasher, owner.request, {
      merchantId, displayName: 'Ana', employeeCode: 'EMP-1',
      assignedBranchIds: [branchId],
    });
    const event = {
      eventId: 'offline-event-1234567890',
      cashierId: cashier.cashierId,
      failedAttempts: 5,
      occurredAt: '2026-09-28T12:00:00.000Z',
    };

    await expect(reportOfflinePinFailures(db, owner.request, [event]))
      .rejects.toMatchObject({ code: 'unauthenticated' });
    expect(await reportOfflinePinFailures(db, device, [event]))
      .toEqual({ acceptedEventIds: [event.eventId] });
    expect(await reportOfflinePinFailures(db, device, [event]))
      .toEqual({ acceptedEventIds: [event.eventId] });
    await expect(reportOfflinePinFailures(db, device, [{
      ...event,
      failedAttempts: 6,
    }])).rejects.toMatchObject({ code: 'already-exists' });
    const reports = await db.collection(`merchants/${merchantId}/auditEvents`)
      .where('action', '==', 'cashier.offlinePinFailed').get();
    expect(reports.size).toBe(1);
    expect(reports.docs[0].get('targetId')).toBe(cashier.cashierId);
    expect(reports.docs[0].get('branchId')).toBe(branchId);
    expect(reports.docs[0].get('details.reportedDeviceTime')).toBe(event.occurredAt);

    await revokePosDevice(db, owner.request, merchantId, activated.deviceId);
    await expect(reportOfflinePinFailures(db, device, [event]))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('does not let one tenant device report against another tenant cashier', async () => {
    const first = await approvedMerchant();
    const second = await approvedMerchant();
    const activated = await activatePosDevice(db, mint, first.owner.request, {
      merchantId: first.merchantId, branchId: first.branchId,
      displayName: 'Counter tablet', platform: 'android', appVersion: '0.1.0',
      operationId: 'activate-1',
    });
    const device = { auth: { uid: `device:${activated.deviceId}`, token: {
      principalType: 'device', merchantId: first.merchantId,
      deviceId: activated.deviceId,
    } } };
    const cashier = await createCashier(db, hasher, second.owner.request, {
      merchantId: second.merchantId, displayName: 'Ana', employeeCode: 'EMP-2',
      assignedBranchIds: [second.branchId],
    });

    await expect(reportOfflinePinFailures(db, device, [{
      eventId: 'offline-event-1234567890',
      cashierId: cashier.cashierId,
      failedAttempts: 5,
      occurredAt: '2026-09-28T12:00:00.000Z',
    }])).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('retries approval, invitation, and activation without duplicate effects', async () => {
    const { owner, admin, applicationId, merchantId, branchId } = await approvedMerchant();
    const review = await reviewMerchantApplication(db, {
      auth: { uid: admin.uid, token: { sarisupplyAdmin: true } },
    }, { applicationId, decision: 'approve', operationId: 'review-1' });
    expect(review.merchantId).toBe(merchantId);
    const input = { merchantId, email: 'manager@example.test',
      allBranches: true, branchIds: [], operationId: 'invite-1' };
    const invite = await createManagerInvitation(db, owner.request, input);
    expect((await createManagerInvitation(db, owner.request, input)).inviteId)
      .toBe(invite.inviteId);
    const activationInput = { merchantId, branchId, displayName: 'Counter',
      platform: 'android', appVersion: '0.1.0', operationId: 'activate-1' };
    const device = await activatePosDevice(db, mint, owner.request, activationInput);
    expect((await activatePosDevice(db, mint, owner.request, activationInput)).deviceId)
      .toBe(device.deviceId);
    expect((await db.collection('merchants').get()).size).toBe(1);
    expect((await db.collection(`merchants/${merchantId}/managerInvites`).get()).size).toBe(1);
    expect((await db.collection(`merchants/${merchantId}/devices`).get()).size).toBe(1);
  });
});
