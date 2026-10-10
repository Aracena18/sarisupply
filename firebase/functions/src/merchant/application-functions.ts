import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { requireHuman } from '../common/authz';
import { toHttpsError } from '../common/errors';
import {
  reviewMerchantApplication as reviewApplication,
  listPendingMerchantApplications as listPendingApplications,
  saveMerchantApplicationDraft as saveDraft,
  submitMerchantApplication as submitApplication,
} from './application-service';

const options = { region: 'asia-southeast1' } as const;

function dataObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Request data must be an object');
  }
  return value as Record<string, unknown>;
}

async function handle<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (!(error instanceof HttpsError)) logger.error('Callable failed', error);
    throw toHttpsError(error);
  }
}

export const saveMerchantApplicationDraft = onCall(options, (request) =>
  handle(async () => {
    const uid = requireHuman(request);
    const data = dataObject(request.data);
    return saveDraft(getFirestore(), uid, {
      applicationId: data.applicationId as string | undefined,
      businessProfile: data.businessProfile as Record<string, unknown>,
      firstBranchDraft: data.firstBranchDraft as Record<string, unknown>,
    });
  }),
);

export const submitMerchantApplication = onCall(options, (request) =>
  handle(async () => {
    const uid = requireHuman(request);
    const data = dataObject(request.data);
    return submitApplication(getFirestore(), uid, data.applicationId as string);
  }),
);

export const listPendingMerchantApplications = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    return listPendingApplications(
      getFirestore(),
      request,
      data.companyId as string,
    );
  }),
);

export const reviewMerchantApplication = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    return reviewApplication(getFirestore(), request, {
      applicationId: data.applicationId as string,
      decision: data.decision as 'approve' | 'reject',
      operationId: data.operationId as string,
      companyId: data.companyId as string | undefined,
      reviewNotes: data.reviewNotes as string | undefined,
    });
  }),
);
