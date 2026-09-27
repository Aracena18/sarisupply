import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { toHttpsError } from '../common/errors';
import {
  createBranch as create,
  deactivateBranch as deactivate,
} from './membership-service';

const options = { region: 'asia-southeast1' } as const;
function dataObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Request data must be an object');
  }
  return value as Record<string, unknown>;
}
async function handle<T>(work: () => Promise<T>): Promise<T> {
  try { return await work(); } catch (error) {
    if (!(error instanceof HttpsError)) logger.error('Branch callable failed', error);
    throw toHttpsError(error);
  }
}

export const createBranch = onCall(options, (request) =>
  handle(() => {
    const data = dataObject(request.data);
    return create(getFirestore(), request, {
      merchantId: data.merchantId as string,
      name: data.name as string,
      code: data.code as string,
      address: data.address as string,
      contactDetails: data.contactDetails as Record<string, unknown> | undefined,
      operatingHours: data.operatingHours as Record<string, unknown> | undefined,
      operationId: data.operationId as string,
    });
  }));

export const deactivateBranch = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    await deactivate(getFirestore(), request, data.merchantId as string, data.branchId as string);
    return { status: 'inactive' };
  }));
