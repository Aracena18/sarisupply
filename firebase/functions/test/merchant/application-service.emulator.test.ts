import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import {
  reviewMerchantApplication,
  saveMerchantApplicationDraft,
  submitMerchantApplication,
} from '../../src/merchant/application-service';

const projectId = 'demo-sarisupply-rules';
const businessProfile = { name: 'Sample Sari Store' };
const firstBranchDraft = {
  name: 'Main Branch', code: 'MAIN', address: 'Davao City',
};

const app = initializeApp({ projectId }, 'application-service-tests');
const db = getFirestore(app);

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Run this test with the Firestore emulator');
  }
});

beforeEach(async () => {
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
});

afterAll(async () => {
  await deleteApp(app);
});

async function pendingApplication(applicantUid = 'owner-1') {
  const draft = await saveMerchantApplicationDraft(db, applicantUid, {
    businessProfile,
    firstBranchDraft,
  });
  await submitMerchantApplication(db, applicantUid, draft.applicationId);
  return draft.applicationId;
}

async function activeAdmin() {
  await db.doc('platformAdmins/admin-1').set({ uid: 'admin-1', status: 'active' });
  return { auth: { uid: 'admin-1', token: { sarisupplyAdmin: true } } };
}

describe('merchant applications', () => {
  it('creates an owned draft and queues it for review', async () => {
    const applicationId = await pendingApplication();
    const snapshot = await db.doc(`merchantApplications/${applicationId}`).get();
    expect(snapshot.data()).toMatchObject({
      applicantUid: 'owner-1', status: 'pending_review',
      businessProfile, firstBranchDraft,
    });
  });

  it('does not let another user edit or submit the application', async () => {
    const applicationId = await pendingApplication();
    await expect(saveMerchantApplicationDraft(db, 'other-1', {
      applicationId, businessProfile, firstBranchDraft,
    })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(submitMerchantApplication(db, 'other-1', applicationId))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('requires both an Admin claim and active record for review', async () => {
    const applicationId = await pendingApplication();
    await expect(reviewMerchantApplication(db, {
      auth: { uid: 'admin-1', token: { sarisupplyAdmin: true } },
    }, { applicationId, decision: 'approve', operationId: 'review-1' }))
      .rejects.toMatchObject({ code: 'permission-denied' });
    await db.doc('platformAdmins/admin-1').set({ uid: 'admin-1', status: 'active' });
    await expect(reviewMerchantApplication(db, {
      auth: { uid: 'admin-1', token: {} },
    }, { applicationId, decision: 'approve', operationId: 'review-1' }))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('approves once even when the same review is retried', async () => {
    const applicationId = await pendingApplication();
    const admin = await activeAdmin();
    const request = { applicationId, decision: 'approve' as const, operationId: 'review-1' };

    const first = await reviewMerchantApplication(db, admin, request);
    const retry = await reviewMerchantApplication(db, admin, request);
    const anotherRetry = await reviewMerchantApplication(db, admin, {
      ...request, operationId: 'review-2',
    });

    expect(retry).toEqual(first);
    expect(anotherRetry).toEqual(first);
    expect(first.status).toBe('approved');
    const merchantId = first.merchantId!;
    expect((await db.doc(`merchants/${merchantId}`).get()).data())
      .toMatchObject({ status: 'active', sourceApplicationId: applicationId });
    expect((await db.collection(`merchants/${merchantId}/branches`).get()).size).toBe(1);
    expect((await db.doc(`merchants/${merchantId}/memberships/owner-1`).get()).data())
      .toMatchObject({ role: 'owner', status: 'active', allBranches: true });
    expect((await db.doc(`users/owner-1/merchantRefs/${merchantId}`).get()).exists)
      .toBe(true);
    expect((await db.collection(`merchants/${merchantId}/auditEvents`).get()).size)
      .toBe(1);
    expect((await db.collection('merchants').get()).size).toBe(1);
  });

  it('lets an applicant revise and resubmit a rejection', async () => {
    const applicationId = await pendingApplication();
    const admin = await activeAdmin();
    await reviewMerchantApplication(db, admin, {
      applicationId, decision: 'reject', operationId: 'review-1',
      reviewNotes: 'Provide the full address',
    });
    await saveMerchantApplicationDraft(db, 'owner-1', {
      applicationId,
      businessProfile,
      firstBranchDraft: { ...firstBranchDraft, address: 'Davao City, Philippines' },
    });
    await submitMerchantApplication(db, 'owner-1', applicationId);
    expect((await db.doc(`merchantApplications/${applicationId}`).get()).data())
      .toMatchObject({ status: 'pending_review', reviewNotes: null });
  });
});
